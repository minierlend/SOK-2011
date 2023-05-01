suppressPackageStartupMessages(library(WDI))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(plyr))
suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(countrycode))

suppressPackageStartupMessages(library(scales))
suppressPackageStartupMessages(library(sjPlot))
suppressPackageStartupMessages(library(sjmisc))
suppressPackageStartupMessages(library(sjlabelled))
suppressPackageStartupMessages(library(knitr))
suppressPackageStartupMessages(library(vtable))
suppressPackageStartupMessages(library(imager))
suppressPackageStartupMessages(library(stargazer))
suppressPackageStartupMessages(library(cowplot))
suppressPackageStartupMessages(library(patchwork))

#   NY.GDP.PCAP.PP.KD (gdppc) = BNP per innbygger (PPP) 
#   NY.ADJ.NNAT.GN.ZS (nsy) = Sparing som andel av BNI (netto)
#   SP.POP.TOTL (poptot) = Befolkningsst�rrelse
#   JI.TLF.TOTL (lf) = St�rrelse p� arbeidskraften
#   SP.POP.GROW (p) = Vekstrate i befolkningen
#   BAR.SCHL.15UP (educ) = Gjennomsnittlig antall �r i skole (befolkning 15+)
#   NE.GDI.FTOT.KD.ZG (gi) = �rlig vekstrate i investeringer
#   NE.EXP.GNFS.KD.ZG (gx) = �rlig vekstrate i eksport
#   NY.ADJ.DRES.GN.ZS (nry) = �rlig reduksjonsrate i naturressurser


# 1. BNP per innbyggere (alle �r) og initial niv� p� BNP per innbyggere. WDI-variabel =  "NY.GDP.PCAP.PP.KD". 
# Velg start�r = 2000 og slutt�r = 2019
df_gdp0<-WDI(
  country = "all",
  indicator = c('gdppc'="NY.GDP.PCAP.PP.KD"),  
  start = 2000,
  end = 2019,
  extra = TRUE, # det � sette "extra = TRUE" f�rer til at vi laster inn ekstra informasjon som vi kan benytte seinere (f.eks. variabelen "region")
  cache = NULL,
  latest = NULL,
  language = "en"
)

df_gdp <- subset(df_gdp0, select = c(country, region, income, iso2c, iso3c, year, gdppc) ) %>%  arrange(iso3c, year) # velg ut relevante variabler
df_gdp <-  df_gdp %>% mutate_all(na_if,"") # Vi �nsker � ta vekk land som ikke har en iso3c kode. Dessverre er manglende observasjoner for "iso3c" (landkode) kodet som "blanks" isteden for "missing". Denne koden korrigerer dette.
df_gdp <- df_gdp[complete.cases( df_gdp$gdppc, df_gdp$iso3c),] # Ta vekk observasjoner som mangler data p� gdppc og iso3c. 
df_gdp = df_gdp  %>%  
  mutate(year = as.numeric(year)) # Se til at year er en numerisk variabel. 

# Noen land har flere observasjoner for samme �r (f.eks afghanistan �r 2010). Vi �nsker � ha �n observasjon per land og �r. 
df_gdp <- df_gdp[!duplicated(df_gdp[c("iso3c", "year", max("gdppc"))]), ]  %>%  arrange(iso3c, year) # Ta vekk duplikater for land og �r, behold observasjonen med st�rst gdppc (denne regelen kan diskuteres)

# Lag et datasett med Y0 (niv� p� BNP per innbyggere i �r 2000)
df_gdp2000  <- df_gdp %>%  arrange(iso3c, year) %>% group_by(iso3c) %>% #Behold den f�rste observasjonen for BNP per innbyggere (Y0)
  slice(1) %>%
  ungroup()
df_gdp2000 = subset(df_gdp2000, select = -c(year) ) # Slett un�dvendige variabler
df_gdp2000 <-   plyr:: rename(df_gdp2000,c("gdppc" = "gdppc0")) # Gi variabeln et nytt navn slik at vi kan identifisere den i datasetet. 

df_gdp <- left_join(df_gdp,df_gdp2000, by=c("country", "iso2c", "iso3c", "region", "income")) # Sett sammen data for BNP per innbygger alle �r, med BNP per innbygger �r 2000.

# 2. Humankapital (gjennomsnittlig antall �r i skole blant befolkningen eldre enn 15 �r). WDI-variabel = BAR.SCHL.15UP 
df_educ0<-WDI(
  country = "all",
  indicator = c('educ'="BAR.SCHL.15UP"),  
  start = 2000,
  end = 2019,
  extra = TRUE,
  cache = NULL,
  latest = NULL,
  language = "en"
)

df_educ <- subset(df_educ0, select = c(country, region, income, iso2c, iso3c, year, educ) ) %>%  arrange(iso3c, year) #Behold n�dvendige variabler
df_educ <- df_educ[complete.cases(df_educ$educ),] %>%  arrange(iso3c, year) # Slett observasjoner med manglende data

df_educ = df_educ %>%  
  arrange(iso3c, year) %>%  # Sorter etter Iso-kode og �r. 
  mutate(educ = as.numeric(educ, na.rm = TRUE)) %>% # Se til at variabelen er numerisk
  ddply("iso3c",transform,
        avg_educ=mean(educ, na.rm = TRUE))  # Beregne gjennomsnittlig �r i skole for tidsperioden 2000 - 2019 for hvert land, basert p� tilgjenglig data (vil v�re 2000.2005,2010)

df_educ <- subset(df_educ, select = c(country, region, income, iso2c, iso3c, avg_educ)) # Her tar jeg vekk variabelen "year". Jeg gj�r dette fordi vi bare har en observasjon p� utdanning per land. Vi �nsker � bruke denne verdi for alle �r. 
df_educ <- df_educ[!duplicated(df_educ[c("iso3c")]), ]  %>%  arrange(iso3c) # Ta vekk duplikater for hvert land.
#######


# 3. Gjennomsnittlig sparing for perioden 2000-2015 (lagg fordi det kan ta litt tid for sparing � bli til investering)
df_nsy0<-WDI(
  country = "all",
  indicator = c( 'nsy'="NY.ADJ.NNAT.GN.ZS"),  
  start = 2000,
  end = 2015,
  extra = TRUE,
  cache = NULL,
  latest = NULL,
  language = "en"
)

df_nsy <- subset(df_nsy0, select = c(country, region, income, iso2c, iso3c, year, nsy) ) %>%  arrange(iso3c, year) #Behold n�dvendige variabler
df_nsy <- df_nsy[complete.cases(df_nsy$nsy),] %>%  arrange(iso3c, year) # Slett observasjoner med manglende data


df_nsy = df_nsy %>%  
  arrange(iso3c, year) %>%  # Sorter etter Iso-kode og �r. 
  mutate(nsy = as.numeric(nsy, na.rm = TRUE)) %>% # Se til at variabelen er numerisk
  ddply("iso3c",transform,
        avg_nsy=mean(nsy, na.rm = TRUE))  # Beregne gjennomsnittlig �r i skole for tidsperioden 2000 - 2019 for hvert land, basert p� tilgjenglig data (vil v�re 2000.2005,2010)

df_nsy <- subset(df_nsy, select = c(country, region, income, iso2c, iso3c, avg_nsy)) # Her tar jeg vekk variabelen "year". Jeg gj�r dette fordi vi bare har en observasjon p� utdanning per land. Vi �nsker � bruke denne verdi for alle �r. 
df_nsy <- df_nsy[!duplicated(df_nsy[c("iso3c")]), ]  %>%  arrange(iso3c) # Ta vekk duplikater for hvert land.

#########

# 4. Vekst i arbeidskraften (n)
df_lf0<-WDI(
  country = "all",
  indicator = c('lf'="JI.TLF.TOTL"),  # lf = labor force
  start = 2000,
  end = 2019,
  extra = TRUE, 
  cache = NULL,
  latest = NULL,
  language = "en"
)

df_lf <- subset(df_lf0, select = c(country, region, income, iso2c, year, lf) ) %>%  arrange(iso2c, year) # velg ut relevante variabler
df_lf <-   plyr:: rename(df_lf,c("iso2c" = "iso3c")) # variabelen som identifiserer land med kode er feil i datasetet. Dette korrigerer dette
df_lf <-  df_lf %>% mutate_all(na_if,"") 
df_lf [df_lf == 0]<-NA
df_lf <- df_lf[complete.cases(df_lf$iso3c, df_lf$lf),] # Ta vekk observasjoner som mangler data p� lf og iso3c. 
df_lf = df_lf  %>%  
  mutate(year = as.numeric(year)) # Se til at year er en numerisk variabel. 

df_lf <- df_lf[!duplicated(df_lf[c("iso3c", "year")]), ]  %>%  arrange(iso3c, year) # Ta vekk duplikater for land og �r

# Ta fram vekstraten i arbeidskraften (n). Vi har ikke data for hvert �r i alle land. 
# For � beregne gjennomsnittlig �rlig vekst m� vi lage en variabel som m�ler antallet tidsperioder mellom hver observasjon.
df_n = df_lf %>%  
  arrange(iso3c, year) %>%  # Sorter p� �r og land
  ddply("iso3c",transform,
        t=c(NA,diff(year)),
        lf_growth=c(NA,diff(log(lf)))) #Vekstrate uten hensyn til tidsintervall

df_n <- df_n[complete.cases(df_n$t, df_n$lf_growth),] # Ta vekk observasjoner som mangler data p� t

#N� kan vi ta fram �rlig vekstrate
df_n = df_n %>%  
  mutate(t = as.numeric(t)) %>%   
  mutate(lf_growth = as.numeric(lf_growth))
df_n <- transform(df_n, n =lf_growth/t)

# gjennomsnittlig vekstrate i arbeidskraften for hvert land
df_n <- df_n %>% # 
  ddply("iso3c",transform,
        avg_n=mean(n, na.rm = TRUE)) #Gjennomsnittlig �rlig vekstrate i arbeidskraften

df_n <- subset(df_n, select = c(iso3c, avg_n) )
df_n <- df_n[!duplicated(df_n["iso3c"]), ]  %>%  arrange(iso3c) # Ta vekk duplikater for land

###########

# 5. Lag et datasett som inneholder BNP data, utdanningsdata, sparing, og arbeidskraftsdata

df <- left_join(df_gdp, df_educ, by=c("country", "iso2c", "iso3c", "region", "income"))
df <- left_join(df, df_nsy, by=c("country", "iso2c", "iso3c", "region", "income"))
df <- left_join(df, df_n, by="iso3c")
df <- subset(df, select = c(country, region, income, iso2c, iso3c, year, gdppc, gdppc0, avg_educ, avg_nsy, avg_n)) # Behold n�dvendige variabler

# Mange observasjoner representerer aggregerte regioner. Vi �nsker � ta vekk disse. Det finnes helt sikkert en bedre m�te � gj�re dette p�. Dette er den m�ten jeg kom p�.
df <- df  %>%  filter(iso2c!='1A' & iso2c !='1W' & iso2c != '4E' & iso2c != '7E' & iso2c !='8S'
                      & iso2c !='B8' & iso2c !='EU' & iso2c !='F1' & iso2c !='OE' & iso2c !='S1' & iso2c !='S2' & iso2c !="S3" 
                      & iso2c !='S4' & iso2c !='T2' & iso2c !='T3' & iso2c !='T4' & iso2c !='T5' & iso2c !='T6' & iso2c !='T7' 
                      & iso2c !='V1' & iso2c !='V2' & iso2c !='V3' & iso2c !='V4' & iso2c !='XC' & iso2c !='XD' & iso2c !='XE' 
                      & iso2c !='XF' & iso2c !='XG' & iso2c !='XH' & iso2c !='XI' & iso2c !='XJ' & iso2c !='XL' & iso2c !='XM' 
                      & iso2c !='XN' & iso2c !='XO' & iso2c !='XP' & iso2c !='XQ' & iso2c !='XT' & iso2c !='XU' & iso2c !='Z4' 
                      & iso2c !='Z7' & iso2c !='ZF'& iso2c !='ZG'  & iso2c !='ZH' & iso2c !='ZI'  & iso2c !='ZJ'  & iso2c !='ZQ'  
                      & iso2c !='ZT'  & iso2c !='Z7')  %>% arrange(iso3c, year) 

#########

# 6. Lag et datasett for resterende variabler.

df_rest0<-WDI(
  country = "all",
  indicator = c('poptot'="SP.POP.TOTL", 'gi'="NE.GDI.FTOT.KD.ZG", 'gx'="NE.EXP.GNFS.KD.ZG", 'nry'="NY.ADJ.DRES.GN.ZS", 'p'="SP.POP.GROW" ),  
  start = 2000,
  end = 2019,
  extra = TRUE,
  cache = NULL,
  latest = NULL,
  language = "en"
)

df_rest0<-df_rest0 %>% mutate_all(na_if,"")
df_rest <- df_rest0[complete.cases( df_rest0$iso3c),]  %>%  arrange(iso2c) 


# Ta vekk observasjoner som ikke representerer land.
df_rest <- df_rest  %>%  filter(iso2c!='1A' & iso2c !='1W' & iso2c != '4E' & iso2c != '7E' & iso2c !='8S'
                                & iso2c !='B8' & iso2c !='EU' & iso2c !='F1' & iso2c !='OE' & iso2c !='S1' & iso2c !='S2' & iso2c !="S3" 
                                & iso2c !='S4' & iso2c !='T2' & iso2c !='T3' & iso2c !='T4' & iso2c !='T5' & iso2c !='T6' & iso2c !='T7' 
                                & iso2c !='V1' & iso2c !='V2' & iso2c !='V3' & iso2c !='V4' & iso2c !='XC' & iso2c !='XD' & iso2c !='XE' 
                                & iso2c !='XF' & iso2c !='XG' & iso2c !='XH' & iso2c !='XI' & iso2c !='XJ' & iso2c !='XL' & iso2c !='XM' 
                                & iso2c !='XN' & iso2c !='XO' & iso2c !='XP' & iso2c !='XQ' & iso2c !='XT' & iso2c !='XU' & iso2c !='Z4' 
                                & iso2c !='Z7' & iso2c !='ZF'& iso2c !='ZG'  & iso2c !='ZH' & iso2c !='ZI'  & iso2c !='ZJ'  & iso2c !='ZQ'  
                                & iso2c !='ZT'  & iso2c !='Z7')  %>% arrange(iso3c, year) 

df_rest <- subset(df_rest, select = c("country", "region", "income", "iso3c", "iso2c", "year", "poptot", "p", "nry", "gi", "gx"))
df_all <- left_join(df, df_rest, by=c("country", "region", "income", "iso2c", "iso3c", "year"))

# Lag en rekkef�lge til variablene slik at det er enklere � f� en oversikt over datamaterialet.
col_order <- c("country",  "region", "income", "iso3c", "iso2c", "year", "gdppc", "gdppc0", "poptot", "p", "avg_n", "avg_nsy", "nry", "gi", "gx", "avg_educ")
df_all <- df_all[, col_order]


########

# Ta fram vekstraten og gjennomsnitt for resterende variabler
df_growth0 = df_all %>%  
  arrange(iso3c, year) %>%  # Sorter p� �r og land
  ddply("iso3c",transform,
        gdpgrowth=c(NA,diff(log(gdppc)))*100) %>%   # �rlig vekstrate i gdppc for hvert land
  mutate(gdpgrowth = as.numeric(gdpgrowth, na.rm = TRUE)) %>% # 
  ddply("iso3c",transform,
        avg_gdpgrowth=mean(gdpgrowth, na.rm = TRUE), #Gjennomsnittlig �rlig vekstrate i BNP per innbygger for hvert land i perioden
        avg_gi=mean(gi, na.rm = TRUE), # Gjennomsnittlig �rlig vekstrate i investeringer for hvert land  i perioden
        avg_nry=mean(nry, na.rm = TRUE),  # Gjennomsnittlig �rlig vekstrate (negativ) i naturressurser for hvert land  i perioden
        avg_gx=mean(gx, na.rm = TRUE),  # Gjennomsnittlig �rlig vekstrate i eksport for hvert land  i perioden
        avg_p=mean(p, na.rm = TRUE))  # Gjennomsnittlig �rlig vekstrate i befolkningen for hvert land  i perioden

#View(df_growth0)
df_growth0 <-  df_growth0 %>% mutate_all(na_if,"") 
df_growth <- df_growth0[complete.cases( df_growth0$country, df_growth0$income, df_growth0$iso3c, df_growth0$avg_gdpgrowth, df_growth0$gdppc0, df_growth0$avg_n, df_growth0$avg_p, df_growth0$avg_nsy, df_growth0$avg_nry,df_growth0$avg_gi, df_growth0$avg_gx, df_growth0$avg_educ),] # Ta vekk land som mangler data 


df_growth <- subset(df_growth, select = c("country",  "region", "income", "iso3c", "iso2c","year", "poptot", "gdppc", "gdppc0", "avg_gdpgrowth", "avg_n", "avg_p", "avg_nsy", "avg_nry", "avg_gi", "avg_gx", "avg_educ"))

# Lage datasettet du vil bruke til analysen din
df_growth2019  <- df_growth %>%  arrange(iso3c, year) %>% group_by(iso3c) %>% 
  slice(n()) %>% # Behold den SISTE observasjonen for hvert land
  ungroup()
head(df_growth2019)

#######

# Lag en variabel som er logaritmen av BNP per innbygger (enklere tolkning og presser sammen fordelingen)
df_growth2019$dppc <-as.numeric(df_growth2019$gdppc)
df_growth2019$ln_gdppc<-log(df_growth2019$gdppc) 
df_growth2019$ln_gdppc0<-log(df_growth2019$gdppc0) 



suppressPackageStartupMessages(library(vtable))


# Velg ut de variabler du vil ha med i tabellen. Her er et eksempel (du skal ta med alle variabler som du har med i den empiriske analysen)
df <- subset(df_growth2019, select = c("avg_gdpgrowth", "avg_p", "avg_n", "avg_nry", "avg_gi", "avg_gx", "avg_educ",
                                       "ln_gdppc"))
# Gi beskrivende navn til variablene (i samme rekkef�lge som de ligger i datasettet)
labs <- c("Gjennomsnitlig �rlig vekstrate i BNP pc 2000-2019 (%)", "Gjennomsnittlig �rlig befolkningsvekst (%)",
          "Gjennomsnittlig vekstrate i arbeidskraft", "Reduksjon i naturressurser", "Gjennomsnittlig vekstrate i investering",
          "Vekstrate i eksport", "Antall �r i skole", "BNP per innbygger(LOG)") 

# Lag tabellen
st(df, labels=labs,
   summ = list(
     c('notNA(x)','mean(x)','sd(x)','min(x)','max(x)'), # Beskriv hvilken statistikk du �nsker � vise
     c('notNA(x)','mean(x)')
   ),
   summ.names = list(
     c('N','Gjennomsnitt','SD','Min','Maks') # Gi navn til kolumnene
   ))


## f� vekk outliners

df <- df_growth2019[complete.cases( df_growth2019$avg_gi, df_growth2019$avg_n),]

Q1gi <- quantile(df$avg_gi, .25 )
Q3gi <- quantile(df$avg_gi, .75)
IQRgi <- IQR(df$avg_gi)

Q1n <- quantile(df$avg_n, .25 )
Q3n <- quantile(df$avg_n, .75)
IQRn <- IQR(df$avg_n)

no_outliers <- subset(df, df$avg_gi > (Q1gi - 1.5*IQRgi) & df$avg_gi < (Q3gi + 1.5*IQRgi) &  df$avg_n > (Q1n - 1.5*IQRn) & df$avg_n < (Q3n + 1.5*IQRn))
dim(no_outliers)


##her er ved null outliners

df_outliners <- subset(no_outliers, select = c("avg_gdpgrowth", "avg_p", "avg_n", "avg_nry", "avg_gi", "avg_gx", "avg_educ",
                                       "ln_gdppc"))
# Gi beskrivende navn til variablene (i samme rekkef�lge som de ligger i datasettet)
labs <- c("Gjennomsnitlig �rlig vekstrate i BNP pc 2000-2019 (%)", "Gjennomsnittlig �rlig befolkningsvekst (%)",
          "Gjennomsnittlig vekstrate i arbeidskraft", "Reduksjon i naturressurser", "Gjennomsnittlig vekstrate i investering",
          "Vekstrate i eksport", "Antall �r i skole", "BNP per innbygger(LOG)") 

# Lag tabellen
st(df_outliners, labels=labs,
   summ = list(
     c('notNA(x)','mean(x)','sd(x)','min(x)','max(x)'), # Beskriv hvilken statistikk du �nsker � vise
     c('notNA(x)','mean(x)')
   ),
   summ.names = list(
     c('N','Gjennomsnitt','SD','Min','Maks') # Gi navn til kolumnene
   ))


###############################PLOTS####################################################


suppressPackageStartupMessages(library(scales))

plot1 <- ggplot(no_outliers, aes(x = avg_nsy , y = ln_gdppc, na.rm = TRUE)) +
  xlab("Gjennomsnittlig sparing") + 
  ylab("BNP per innbygger 2019(log)") + 
  geom_point(aes(size = poptot, color = region), alpha = 0.5) + # St�rrelse (farge) p� bobblene avhenger befolkningsst�rrelse (region)
  scale_size_area(guide = "none", max_size = 14) + #Ta vekk legend for befolkningsst�rrelse # Bestem font-st�rrelse p� legend
  scale_colour_manual(values = rainbow(9)) +# Velg farger til bobblene
  theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(), panel.background = element_rect(fill = 'white'))+
  labs(title = "Forholdet mellom sparing og BNP per innbygger") +
  geom_smooth(method="lm", se = FALSE)+
  theme_grey()# logaritmere BNP pc og velg hvilke "ticks" som skal vises
plot1

###Vekstrate/bnp 

plot2 <- ggplot(no_outliers, aes(x = avg_p , y = ln_gdppc, na.rm = TRUE)) +
  xlab("Gjennomsnittlig vekstrate i befolkning") + 
  ylab("BNP per innbygger 2019(log)") + 
  geom_point(aes(size = poptot, color = region), alpha = 0.5) + # St�rrelse (farge) p� bobblene avhenger befolkningsst�rrelse (region)
  scale_size_area(guide = "none", max_size = 14) + #Ta vekk legend for befolkningsst�rrelse # Bestem font-st�rrelse p� legend
  scale_colour_manual(values = rainbow(9)) +# Velg farger til bobblene
  theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(), panel.background = element_rect(fill = 'white'))+
  labs(title = "Forholdet mellom vekstrate i befolkningen og BNP per innbygger") +
  geom_smooth(method="lm", se = FALSE)+
  theme_grey()# logaritmere BNP pc og velg hvilke "ticks" som skal vises
plot2

##BNP/humMANKAPITAL 


plot3 <- ggplot(no_outliers, aes(x = avg_educ , y = ln_gdppc, na.rm = TRUE)) +
  xlab("Gjennomsnittlig antall �r i utdanning") + 
  ylab("BNP per innbygger 2019(log)") + 
  geom_point(aes(size = poptot, color = region), alpha = 0.5) + # St�rrelse (farge) p� bobblene avhenger befolkningsst�rrelse (region)
  scale_size_area(guide = "none", max_size = 14) + #Ta vekk legend for befolkningsst�rrelse # Bestem font-st�rrelse p� legend
  scale_colour_manual(values = rainbow(9)) +# Velg farger til bobblene
  theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(), panel.background = element_rect(fill = 'white'))+
  labs(title = "Forholdet mellom utdanningsniv� og BNP per innbygger") +
  geom_smooth(method="lm", se = FALSE)+
  theme_grey()# logaritmere BNP pc og velg hvilke "ticks" som skal vises
plot3



####vekstrate bnp per innbygger og sparing


plot4 <- ggplot(no_outliers, aes(x = avg_nsy , y = avg_gdpgrowth, na.rm = TRUE)) +
  xlab("Gjennomsnittlig sparing ") + 
  ylab("Vekstraten i BNP per innbygger") + 
  geom_point(aes(size = poptot, color = region), alpha = 0.5) + # St�rrelse (farge) p� bobblene avhenger befolkningsst�rrelse (region)
  scale_size_area(guide = "none", max_size = 14) + #Ta vekk legend for befolkningsst�rrelse # Bestem font-st�rrelse p� legend
  scale_colour_manual(values = rainbow(9)) +# Velg farger til bobblene
  theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(), panel.background = element_rect(fill = 'white'))+
  labs(title = "Forholdet mellom gjennomsnittlig sparing og vekstraten i BNP per innbygger") +
  geom_smooth(method="lm", se = FALSE)+
  theme_grey()# logaritmere BNP pc og velg hvilke "ticks" som skal vises
plot4


##################
plot5 <- ggplot(no_outliers, aes(x = avg_educ , y = avg_gdpgrowth, na.rm = TRUE)) +
  xlab("Gjennomsnittlig utdanningsniv�, humankapital ") + 
  ylab("Vekstraten i BNP per innbygger") + 
  geom_point(aes(size = poptot, color = region), alpha = 0.5) + # St�rrelse (farge) p� bobblene avhenger befolkningsst�rrelse (region)
  scale_size_area(guide = "none", max_size = 14) + #Ta vekk legend for befolkningsst�rrelse # Bestem font-st�rrelse p� legend
  scale_colour_manual(values = rainbow(9)) +# Velg farger til bobblene
  theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(), panel.background = element_rect(fill = 'white'))+
  labs(title = "Forholdet mellom humankapitalen og vekstraten i BNP per innbygger") +
  geom_smooth(method="lm", se = FALSE)+
  theme_grey()# logaritmere BNP pc og velg hvilke "ticks" som skal vises
plot5



####regresjon 



outliers <-lm(avg_gdpgrowth ~ avg_educ + avg_n +
                avg_p + avg_nsy  + avg_nry + avg_gi + ln_gdppc0, data = df_growth2019)

summary(outliers)
tab_model(outliers, CSS = css_theme("cells"))





no_outlierss <-lm(avg_gdpgrowth ~ avg_educ + avg_n + avg_p + avg_nsy  + avg_nry
                  + avg_gi + ln_gdppc0, data = no_outliers)

summary(no_outlierss)
tab_model(no_outlierss, CSS = css_theme("cells"))


export <-lm(avg_gdpgrowth ~ avg_educ + avg_n + avg_p + avg_nsy  + avg_nry + avg_gi + avg_gx + ln_gdppc0, data = no_outliers)

summary(export)
tab_model(export, CSS = css_theme("cells"))

summary(model1)








#####TIL INDTRODUKJSONEN TATT FRA STATESTIKK EKSAMEN 

rm(list=ls())
require(gapminder) || {install.packages("gapminder") ; library(gapminder)}
gapminder <- gapminder
gapminder <- janitor::clean_names(gapminder)
names(gapminder)
#filtrer
gapminded_2007 <- gapminder %>% 
  filter(year =="2007")

#
gapminder %>%
  group_by(continent)%>% 
  summarise(avg_pop= mean(pop),
            avg_gpd_per = mean(gdp_percap),
            avg_lifeexp= mean(life_exp))%>% 
  rename(pop = avg)





gapminded_2007

##lager plot
gapminded_2007 %>%
  ggplot(aes(x=gdp_percap, y = life_exp, size = pop, color = continent))+
  geom_point(alpha=0.5)+
  #skalleringen 
  scale_size(range = c(2,10), name = "Population (M)") +
  labs(title = "Relationship between life expectancy and income, 2007",
       x = "GDP per capita ($)",
       y = "Life expectency (years)")+
  scale_x_continuous(labels = scales::dollar)











