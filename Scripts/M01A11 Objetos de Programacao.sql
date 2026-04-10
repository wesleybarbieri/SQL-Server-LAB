/************************************************************
 Autor: Landry Duailibe

 O BRUNO E GAY

 Hands On: Views
*************************************************************/
use Aula
go

/***********************************
 Cria tabelas para o Hands On
************************************/
set nocount on

-- Tabela Customer
DROP TABLE IF exists dbo.Customer
go
CREATE TABLE dbo.Customer (
CustomerID int not null CONSTRAINT pk_Customer PRIMARY KEY, 
Title nvarchar(8) null, 
FirstName nvarchar(50) null, 
MiddleName nvarchar(50) null, 
LastName nvarchar(50) null,
[Name] nvarchar(160) null,
Excluido bit not null DEFAULT (0)) 
go

-- Carrega linhas a partir do AdventureWorks
INSERT dbo.Customer (CustomerID, Title, FirstName, MiddleName, LastName, [Name])
SELECT c.CustomerID, Title, FirstName, MiddleName, LastName, FirstName + isnull(' ' + MiddleName,'') + isnull(' ' + LastName,'') as [Name]
FROM AdventureWorks.Sales.Customer c
JOIN AdventureWorks.Person.Person p on p.BusinessEntityID = c.PersonID
go

-- Tabela SalesOrderHeader
DROP TABLE IF exists dbo.SalesOrderHeader
go
CREATE TABLE dbo.SalesOrderHeader(
SalesOrderID int NOT NULL identity CONSTRAINT pk_SalesOrderHeader PRIMARY KEY,
OrderDate datetime NOT NULL,
Status tinyint NOT NULL,
OnlineOrderFlag bit NOT NULL,
SalesOrderNumber char(200) NOT NULL,
CustomerID int NOT NULL,
SalesPersonID int NULL,
TerritoryID int NULL,
SubTotal money NOT NULL,
TaxAmt money NOT NULL,
Freight money NOT NULL,
TotalDue money NOT NULL,
Comment nvarchar(128) NULL)
go

-- Carrega linhas a partir do AdventureWorks
INSERT dbo.SalesOrderHeader (OrderDate, [Status], OnlineOrderFlag, SalesOrderNumber, CustomerID, SalesPersonID, TerritoryID, SubTotal, TaxAmt, Freight, TotalDue, Comment)
SELECT OrderDate, Status, OnlineOrderFlag, 
SalesOrderNumber, CustomerID, SalesPersonID, TerritoryID,  
SubTotal, TaxAmt, Freight, TotalDue, Comment
FROM AdventureWorks.Sales.SalesOrderHeader
go

set nocount off
-- daqui para cima pode roda tudo
/************************* FIM Prepara Hands On ******************************/


/******************************
 Hands On VIEW
*******************************/
-- Consulta completa traz o total de vendas ordenado pela data 
SELECT c.Name as Customer, h.SalesOrderID, h.OrderDate, h.TotalDue
FROM dbo.SalesOrderHeader h
JOIN dbo.Customer c on c.CustomerID = h.CustomerID
WHERE h.OrderDate >= '20060101' and h.OrderDate < '20080101'
ORDER BY h.TotalDue desc
go

CREATE or ALTER VIEW dbo.vw_CustomerOrder
AS
SELECT c.Name as Customer, h.SalesOrderID, h.OrderDate, h.TotalDue
FROM dbo.SalesOrderHeader h
JOIN dbo.Customer c on c.CustomerID = h.CustomerID
go
-- quando fazer o select na view passando a condição e a mesma coisa de executar o select anterior 
-- o sql vai juntar as duas querys para execução, e não traz um e depois o outro 
SELECT Customer, SalesOrderID, OrderDate, TotalDue
FROM dbo.vw_CustomerOrder
WHERE OrderDate >= '20060101' and OrderDate < '20080101'
ORDER BY TotalDue desc

-- Acessado a definição original da View
SELECT OBJECT_DEFINITION(OBJECT_ID('dbo.vw_CustomerOrder','V'))

EXEC sp_helptext 'dbo.vw_CustomerOrder'

-- Exclui a View
DROP VIEW dbo.vw_CustomerOrder
go

/***************************************
 Hands On STORED PROCEDURE
****************************************/
SELECT * FROM dbo.Customer

-- Stored Procedure para exclusão lógica
-- são exclusões logicas utilizando valores binarios para determinadas condições ex
-- a aplicação esta configurada para, quando for 0, não foi excluido, quando for 1, ele foi excluido e a app não considera mais os dados da tabela 
-- porem os dados ainda permanesse fisicamente na tabela, se precisar sera colocado como 0 e utilizado novamente
go
CREATE or ALTER PROC dbo.spu_Customer_DELETE
-- depois do nome da PROC, e asntes do AS e declarado o parametro da PROC
-- depois do valor do parametro vc pode adicionar uma virgula para adicionar mais um parametro
@CustomerID int 
as
set nocount on -- para não aparecer as linhas modificadas na aplicação, para não gera um trafeco de rede desnecessario
			-- e ate mesmo no ssms em mensagens abaixo
UPDATE dbo.Customer SET Excluido = 1 
WHERE CustomerID = @CustomerID
go

-- Exclusão lógica de um Cliente
-- como e executado a PROC e passando um valor ao parametro
EXEC dbo.spu_Customer_DELETE @CustomerID = 11000

SELECT * FROM dbo.Customer
WHERE CustomerID = 11000
-- como seria visto pela app
SELECT count(*) FROM dbo.Customer -- 19.119
WHERE Excluido = 0 -- 19118

-- Exclui Procedure
DROP PROC dbo.spu_Customer_DELETE
go
/***************************************
 Hands On FUNCTION
****************************************/
-- AS FUNÇÕES NÃO ATUALIZÃO DADOS, E APENAS PARA VISUALIZAR, SO A PROC QUE ATUALIZA
/*********************
 Função Escalar
*********************/
-- o parametro e definido dentro do (), pode ser mais de um separando por virgulas, e tipos de dados
CREATE or ALTER FUNCTION dbo.UltimoDiaMesAnterior (@Data date)
RETURNS date -- como retorna apans um valor tem q informar o tipo de valor que neste exemplo e DATA
AS 
BEGIN -- para marca o corpo da função, e pode ser implementado varios comandos
  RETURN dateadd(day, - DAY(@Data), @Data) -- PARA SUBTRAIR A DATA, com o valor passado pelo parametro 
END
go

SELECT dbo.UltimoDiaMesAnterior(getdate()), getdate()
SELECT dbo.UltimoDiaMesAnterior('2017-01-01')

-- Exclui
DROP FUNCTION dbo.UltimoDiaMesAnterior

/*********************************
 Função Table-Valued
 tambem conhecida como view parametrizada, como no oracle
**********************************/
go
CREATE OR ALTER FUNCTION dbo.fnu_CustomerOrder_Day (@Data date)
RETURNS TABLE --  vai retornar o tipop TABLE
AS 
RETURN (
SELECT c.Name as Customer, h.SalesOrderID, h.OrderDate, h.TotalDue
FROM dbo.SalesOrderHeader h
JOIN dbo.Customer c on c.CustomerID = h.CustomerID
WHERE h.OrderDate >= @Data and h.OrderDate < dateadd(dd,1,@Data)) -- utilizando o parametro de entrada 
-- dateadd calcula data, que no caso passando o valor de 1 ele soma um dia para frente
go

SELECT * FROM dbo.fnu_CustomerOrder_Day('20060101')

-- Excclui Função
DROP FUNCTION dbo.fnu_CustomerOrder_Day



/***************************************
 Hands On TRIGGER
****************************************/

/*******************************
 Cria tabela para Auditoria
********************************/
DROP TABLE IF exists dbo.AuditCustomer
go
-- TRUNCATE TABLE dbo.AuditCustomer
CREATE TABLE dbo.AuditCustomer (
AuditCustomer_ID int NOT NULL IDENTITY(1,1) PRIMARY KEY,
TipoAtualizacao varchar(20) NOT NULL,
UserLogin varchar(100) NULL,
Host varchar(100) NULL,
CustomerID int NOT NULL,
Title nvarchar(8) NULL,
FirstName nvarchar(50) NOT NULL,
MiddleName nvarchar(50) NULL,
Lastname nvarchar(50) NULL,
[Name] nvarchar(160) NULL,
Excluido bit NULL)
go
-- SELECT * FROM dbo.AuditCustomer

/*******************************
 Trigger INSERT/UPDATE
********************************/
-- DROP TRIGGER trg_Customer_Audit
/* Durante a execução da triger o sql disponibiliza duas tabelinhas, fora disso não e possivel acessar as tabelas 
 as tabelas são "deleted" e "inserted"
 se a operação for inserte ele vai criar uma tabela chamada inseted com a mesma estrutura da tabela em que foi criada a triger com uma linha incluida.
 com isso dentro da triger vc  consegue descobrir o inserte do ususario, e quais dados ele incluiu fazendo um select nessa tabela de inserted.
 quando e excluizão ele cria a deleted da mesma forma da inseted com as linhas alteradas 
 No update fica as duas tabelas disponiveis na iserted tem a linha alterada apos o update, e na deleted antes de fazer a alteração
 */
go
CREATE or ALTER TRIGGER trg_Customer_Audit
ON dbo.Customer AFTER INSERT, UPDATE  -- para definir qual o tipo de operação a triger vai desparar
as
set nocount on -- para não ficar rnviando as alterações das etapas

DECLARE @TipoAtualizacao varchar(20)

IF exists (SELECT * FROM deleted) -- vai verifica sem tem algo na deleted se não passa para a proxima condição
	SET @TipoAtualizacao = 'UPDATE'
ELSE
	SET @TipoAtualizacao = 'INSERT' -- se tiver alteração na inserted vai executar essa condição, e vice e versa

INSERT dbo.AuditCustomer
(TipoAtualizacao, UserLogin, Host, 
CustomerID, Title, FirstName, MiddleName, Lastname, [Name], Excluido)

SELECT @TipoAtualizacao,system_user as UserLogin, host_name() as Host,
CustomerID, Title, FirstName, MiddleName, Lastname, [Name], Excluido
FROM Inserted
go

-- Executando alterações

SELECT * FROM dbo.Customer ORDER BY CustomerID desc

-- Provoca disparo da Trigger operação INSERT
INSERT dbo.Customer (CustomerID, Title, FirstName, MiddleName, Lastname, [Name], Excluido)
VALUES (90000,'Mr.','Jose','M.','da Silva','Jose M. da Silva',0)

-- Provoca disparo da Trigger operação UPDATE
UPDATE  dbo.Customer SET Title = 'Sr.'
WHERE CustomerID = 90000

-- Verifica tabela de Auditoria
SELECT * FROM dbo.Customer WHERE CustomerID = 90000

SELECT * FROM dbo.AuditCustomer


/******************
 Exclui Tabelas
*******************/
DROP TABLE IF exists dbo.Customer
DROP TABLE IF exists dbo.AuditCustomer
DROP TABLE IF exists dbo.SalesOrderHeader
