#Primero vamos a copiar nuestra tabla para poder manipularla con facilidad
SELECT *
FROM dirty_cafe_sales;

CREATE TABLE `dirty_cafe_sales_stage` (
  `Transaction ID` text,
  `Item` text,
  `Quantity` text,
  `Price Per Unit` text,
  `Total Spent` text,
  `Payment Method` text,
  `Location` text,
  `Transaction Date` text,
  row_num INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

#Ahora vamos a revisar si hay valores duplicados
INSERT INTO dirty_cafe_sales_stage
SELECT *,
ROW_NUMBER()OVER(PARTITION BY `Transaction ID`, Item, Quantity, `Price Per Unit`, `Total Spent`, `Payment Method`, Location, `Transaction Date`)
FROM dirty_cafe_sales;

SELECT * 
FROM dirty_cafe_sales_stage
WHERE row_num > 1;

#Ahora empezaremos con la estandarización de los datos
SELECT DISTINCT `Transaction ID`
FROM dirty_cafe_sales_stage
ORDER BY `Transaction ID` DESC;

SELECT DISTINCT Item
FROM dirty_cafe_sales_stage;

#Hicimos este cambio ya que se encontraban valores en blanco, algunos con mensaje de error y otros como UNKNOWN, entonces pusimos un mismo nombre para todo este tipo de datos
UPDATE dirty_cafe_sales_stage
SET Item = 'NA'
WHERE Item IN ('','UNKNOWN','ERROR');


SELECT DISTINCT Quantity
FROM dirty_cafe_sales_stage;

UPDATE dirty_cafe_sales_stage
SET Quantity = '0'
WHERE Quantity IN ('','ERROR','UNKNOWN');


SELECT DISTINCT `Price Per Unit`
FROM dirty_cafe_sales_stage;

UPDATE dirty_cafe_sales_stage
SET `Price Per Unit` = '0'
WHERE `Price Per Unit` IN  ('', 'ERROR','UNKNOWN');


SELECT DISTINCT `Total Spent`
FROM dirty_cafe_sales_stage;

UPDATE dirty_cafe_sales_stage
SET `Total Spent` = '0'
WHERE `Total Spent` IN  ('', 'ERROR','UNKNOWN');


SELECT DISTINCT `Payment Method`
FROM dirty_cafe_sales_stage;

UPDATE dirty_cafe_sales_stage
SET `Payment Method` = 'NA'
WHERE `Payment Method` = '0';


SELECT DISTINCT `Location`
FROM dirty_cafe_sales_stage;

UPDATE dirty_cafe_sales_stage
SET `Location` = 'NA'
WHERE `Location` IN  ('', 'ERROR','UNKNOWN');


SELECT DISTINCT `Transaction Date`
FROM dirty_cafe_sales_stage;

UPDATE dirty_cafe_sales_stage
SET `Transaction Date` = NULL
WHERE `Transaction Date` IN  ('', 'ERROR','UNKNOWN');

SELECT * 
FROM dirty_cafe_sales_stage
WHERE Item = 'Cake'; 

#Vamos a rellenar los datos vacíos en las columnas numéricas que podamos rellenar
 
UPDATE dirty_cafe_sales_stage
SET Quantity = 
	CASE
		WHEN `Price Per Unit` != 0 THEN`Total Spent`/`Price Per Unit`
	END;
    
UPDATE dirty_cafe_sales_stage
SET `Price Per Unit` = 
	CASE
		WHEN `Total Spent` != 0 THEN`Total Spent`/`Quantity`
	END;
    
UPDATE dirty_cafe_sales_stage
SET `Total Spent` = `Quantity` * `Price Per Unit`;

#También vamos a llenar el campo Item para poder curar la información lo más que podamos
#Lo que vamos a hacer es buscar por el precio por unidad y si hay sólo una coincidencia ya sabremos a qué producto corresponde el valor NA
CREATE PROCEDURE fill_item(new_item_par TEXT, price_par DOUBLE)
UPDATE dirty_cafe_sales_stage
SET Item = new_item_par
WHERE Item = 'NA' AND `Price Per Unit` = price_par;

CALL fill_item('Salad',5);
CALL fill_item('Cookie',1);
CALL fill_item('Tea',1.5);
CALL fill_item('Coffee',2);

#Algunos valores NA no se pudieron tratar debido a que había más de una coincidencia y no pudimos averiguar a qué Item pretenecía 
SELECT DISTINCT `Price Per Unit`
FROM dirty_cafe_sales_stage
WHERE Item = 'NA';


#Vamos a borrar los valores que no pudimos tratar y que no nos aportan nada
DELETE
FROM dirty_cafe_sales_stage
WHERE `Price Per Unit` IS NULL AND `Total Spent` IS NULL;


#Ahora daremos el formato correcto a nuestros datos
ALTER TABLE dirty_cafe_sales_stage
	MODIFY Quantity INT,
    MODIFY `Price Per Unit` DOUBLE,
    MODIFY `Total Spent` DOUBLE,
    MODIFY `Transaction Date` DATE;

#Empezaremos a eliminar las columnas sobrantes
ALTER TABLE dirty_cafe_sales_stage DROP COLUMN row_num; 

#-----------------------------------------------------------------------------------------------------
#A continuación procederemos con el Análisis Exploratorio de Datos
SELECT * 
FROM dirty_cafe_sales_stage
ORDER BY `Total Spent` DESC
LIMIT 1;
# La venta más alta registrada equivale a $25 con una Transaction ID de 'TXN_9882485'

SELECT SUM(`Total Spent`)
FROM dirty_cafe_sales_stage;  
#En total de ventas se registran $84763.5

#Ahora crearemos una tabla a parte donde nos encargaremos de usar todo lo relacionado con los Items
CREATE TABLE products_analisis(
Item TEXT,
Quantity INT,
`Price Per Unit` DOUBLE,
`Total Spent` DOUBLE);

INSERT INTO products_analisis
SELECT Item, SUM(Quantity) AS Quantity,`Price Per Unit`,
SUM(`Total Spent`) AS `Total Spent`
FROM dirty_cafe_sales_stage
GROUP BY Item, `Price Per Unit`;

#Ahora veremos cuál ha sido el producto que reporta más ventas con respecto a unidades
SELECT * 
FROM products_analisis
ORDER BY Quantity ASC;
#El producto más vendido fue Coffee con un total de 3562 unidades y reportando unos ingresos de $7124
#El producto menos vendido fue el Smoothie con 2951 unidades 

#Ahora veremos cuál ha sido el producto que reporta más ingresos
SELECT * 
FROM products_analisis
ORDER BY `Total Spent` DESC;
#El producto que reporta más ventas en cuanto a dinero es Salad con $17345 y 3469 unidades


#Vamos a averiguar cuál es el método de pago que registra más ingresos 
SELECT `Payment Method`, SUM(`Total Spent`) AS `Total Spent` 
FROM dirty_cafe_sales_stage
GROUP BY `Payment Method`
ORDER BY `Total Spent` DESC;
#El método de pago que registra más ingresos es Digital Wallet con un total de $18549 

#Vamos a ver cuál es el método de pago más usado
SELECT `Payment Method`, COUNT(*) AS Quantity
FROM dirty_cafe_sales_stage
GROUP BY `Payment Method`
ORDER BY Quantity DESC;
#Con base a los registros el método de pago más usado es Digital Wallet 


#Vamos a ver en qué lugar se compra más en cuánto a cantidad, si en la tienda o a domicilio
SELECT `Location`, COUNT(*) AS Quantity
FROM dirty_cafe_sales_stage
GROUP BY `Location`
ORDER BY Quantity DESC;
#El lugar que registra más cantidad de ventas es dentro de la tienda con un total de 2723 pero el domicilio está muy cerca con un total de 2715. Por ende acá no hay una diferencia significativa (Tener en cuenta: Hay 3547 valores NA por lo cuál no podemos saber a qué locación pertenecen)

#Vamos a ver en qué lugar se compra más en cuánto a ingresos
SELECT Location, SUM(`Total Spent`) AS total_spent
FROM dirty_cafe_sales_stage
GROUP BY Location
ORDER BY total_spent DESC;
#Tenemos la misma situación, donde se reportan más ingresos es en la tienda pero contamos con una cantidad de $31.792 en valores desconocidos lo cuál afecta en gran medida el estudio

 #Ahora vamos a identificar los meses con mayor ingreso y menor ingreso
 SELECT MONTH(`Transaction Date`), SUM(`Total Spent`) AS total_spent
 FROM dirty_cafe_sales_stage
 GROUP BY MONTH(`Transaction Date`)
 ORDER BY total_spent DESC;
 
 #MAYOR INGRESO: Junio $6742.5
 #MENOR INGRESO: Febrero $6014.5
 
