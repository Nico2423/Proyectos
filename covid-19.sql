#Copiamos la tabla original para poder manipular libremente la Data
CREATE TABLE `raw_data_stage` (
  `ï»¿iso_code` text,
  `location` text,
  `date` text,
  `total_cases` int DEFAULT NULL,
  `total_deaths` int DEFAULT NULL,
  `stringency_index` int DEFAULT NULL,
  `population` int DEFAULT NULL,
  `gdp_per_capita` double DEFAULT NULL,
  `human_development_index` double DEFAULT NULL,
  `MyUnknownColumn` text,
  `MyUnknownColumn_[0]` text,
  `MyUnknownColumn_[1]` text,
  `MyUnknownColumn_[2]` text,
  `MyUnknownColumn_[3]` text,
  row_num INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

SELECT * FROM raw_data;

#Usamos una Window Function para determinar si hay copias
INSERT INTO raw_data_stage
SELECT *,
ROW_NUMBER() OVER(PARTITION BY ï»¿iso_code, location, date, total_cases, total_deaths, stringency_index, population, gdp_per_capita,
 human_development_index, MyUnknownColumn, `MyUnknownColumn_[0]`, `MyUnknownColumn_[1]`, `MyUnknownColumn_[2]`, `MyUnknownColumn_[3]`) AS row_num
 FROM raw_data;
 
 #Todos los números que se encuentren en la columna row_num y que sean mayores que 1 son copias
 SELECT * FROM raw_data_stage
 WHERE row_num > 1;
 
 #Cambiaremos el nombre de la columna para poder trabajarla con mayor facilidad
ALTER TABLE raw_data_stage
CHANGE `ï»¿iso_code` iso_code TEXT;

 #Ahora verificaremos si hay algún tipo de error de tipificación en nuestras columnas
 SELECT DISTINCT iso_code
 FROM raw_data_stage
 ORDER BY iso_code ASC;
 
 SELECT DISTINCT location
 FROM raw_data_stage
 ORDER BY location ASC;

UPDATE raw_data_stage
SET `date` = STR_TO_DATE(`date`,'%Y-%m-%d');

ALTER TABLE raw_data_stage
MODIFY COLUMN `date` DATE;

#Ahora vamos a examinar y tratar valores nulos y en blanco
SELECT *
FROM raw_data_stage
WHERE `date` IS NULL; 

SELECT *
FROM raw_data_stage
WHERE total_cases IS NULL OR total_cases = ''; 

SELECT *
FROM raw_data_stage
WHERE total_deaths IS NULL OR total_deaths = ''; 

SELECT *
FROM raw_data_stage
WHERE population IS NULL OR population = '';

SELECT DISTINCT MyUnknownColumn
FROM raw_data_stage;

SELECT *
FROM raw_data_stage
WHERE MyUnknownColumn = '#NUM!';

#Hay 66 registros los cuáles no tienen estos dos criterios que son los más importantes para el análisis, por ende los vamos a eliminar
SELECT COUNT(*)
FROM raw_data_stage
WHERE total_cases = '' AND total_deaths = '';

DELETE 
FROM raw_data_stage
WHERE total_cases = '' AND total_deaths = '';

#Vamos a cambiar el valor '#NUM!' por un 0 para que cumpla con el formato
SELECT * 
FROM raw_data_stage
WHERE `MyUnknownColumn_[0]` = '#NUM!';

UPDATE raw_data_stage
SET `MyUnknownColumn_[0]` = 0
WHERE `MyUnknownColumn_[0]`= '#NUM!';

#------------------------------------------------------------------------------------------------------
#Ahora empezaremos con el Análisis Exploratorio de Datos

#Primero veremos el máximo en cuanto a total_cases y total_deaths
SELECT MAX(total_cases), MAX(total_deaths)
FROM raw_data_stage; 

#Con esto podemos ver cuál fue el país con la cifra máxima de muertes y de casos, cuyo dato corresponde a Argentina
SELECT * 
FROM raw_data_stage
ORDER BY total_cases DESC
LIMIT 1;

#Creamos una tabla a parte para analizar los casos respecto a los países agrupados 
CREATE TABLE country_data(
location VARCHAR(50),
total_cases INT,
total_deaths INT
);

INSERT INTO country_data
SELECT location, SUM(total_cases) AS total_cases, SUM(total_deaths) AS total_deaths
FROM raw_data_stage
GROUP BY location;


#Ahora vamos a identificar los 3 países que se vieron más afectados por el COVID-19
SELECT location, total_cases, total_deaths
FROM country_data
ORDER BY total_cases DESC
LIMIT 3; 

SELECT location, total_cases, total_deaths
FROM country_data
GROUP BY location, total_cases, total_deaths
ORDER BY total_deaths DESC
LIMIT 3; 


#La lista en cuánto a número de infectados es:
#1. Argentina: '37869580'
#2. Bangladesh: '30696689'
#3. Bélgica: '15190415'

#La lista en cuánto a número de muertes es:
#1. Bélgica: '1798461'
#2. Argentina: '829634'
#3. Bolivia: '511407'

#Ahora analizaremos el porcentaje de muertes de los países encontrados en el dataset
SELECT location, total_cases, total_deaths, ROUND((total_deaths/total_cases)*100,2) AS percentage_deaths
FROM country_data
GROUP BY location, total_cases, total_deaths
ORDER BY percentage_deaths DESC;

#El país con el porcentaje más alto de muertes pertenece a Bélgica con 11.84%


#Ahora veremos cuál fue el mes en el cuál se presentaron más casos y más muertes por COVID-19
SELECT MONTH(`date`) AS `Month`, SUM(total_cases) AS total_cases, SUM(total_deaths) AS total_deaths
FROM raw_data_stage
GROUP BY MONTH(`date`)
ORDER BY total_cases DESC
LIMIT 1;

SELECT MONTH(`date`) AS `Month`, SUM(total_cases) AS total_cases, SUM(total_deaths) AS total_deaths
FROM raw_data_stage
GROUP BY MONTH(`date`)
ORDER BY total_deaths DESC
LIMIT 3;

#El mes donde se presentaron más casos y más muertes fue en el mes de septiembre con números de: 
#Casos = '44.982.867'
#Muertes = '1.234.968'

