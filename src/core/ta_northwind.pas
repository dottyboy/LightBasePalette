unit ta_northwind;
{ Primjer baze "Northwind Traders" izgraden samim builderom: tablice s tipovima i
  stranim kljucevima, podaci, forme (carobnjaci), upiti, izvjesca, izbornik.
  Podaci su smanjeni uzorak (30 kupaca, 40 proizvoda, 220 narudzbi) s poznatim
  nazivima iz klasicnog Northwinda; narudzbe su generirane deterministicki. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ta_meta;

{ Gradi cijelu bazu u otvorenoj (praznoj) bazi. ALog dobiva sto je izradeno. }
function BuildNorthwind(ADb: TAppDb; ALog: TStrings): Boolean;

implementation

uses
  DateUtils, contnrs, ta_types, ta_formdef, ta_reportdef, ta_wizardgen, ta_bizgen, ta_app,
  ta_crosstab, ta_audit, ta_controls;

const
  Categories: array[1..8] of string = (
    'Beverages|Soft drinks, coffees, teas, beers, and ales',
    'Condiments|Sweet and savory sauces, relishes, spreads, and seasonings',
    'Confections|Desserts, candies, and sweet breads',
    'Dairy Products|Cheeses',
    'Grains/Cereals|Breads, crackers, pasta, and cereal',
    'Meat/Poultry|Prepared meats',
    'Produce|Dried fruit and bean curd',
    'Seafood|Seaweed and fish');

  Shippers: array[1..3] of string = (
    'Speedy Express|(503) 555-9831', 'United Package|(503) 555-3199', 'Federal Shipping|(503) 555-9931');

  { prezime|ime|titula|rodjen|zaposlen|grad|drzava|nadredjeni }
  Employees: array[1..9] of string = (
    'Davolio|Nancy|Sales Representative|1948-12-08|1992-05-01|Seattle|USA|2',
    'Fuller|Andrew|Vice President, Sales|1952-02-19|1992-08-14|Tacoma|USA|0',
    'Leverling|Janet|Sales Representative|1963-08-30|1992-04-01|Kirkland|USA|2',
    'Peacock|Margaret|Sales Representative|1937-09-19|1993-05-03|Redmond|USA|2',
    'Buchanan|Steven|Sales Manager|1955-03-04|1993-10-17|London|UK|2',
    'Suyama|Michael|Sales Representative|1963-07-02|1993-10-17|London|UK|5',
    'King|Robert|Sales Representative|1960-05-29|1994-01-02|London|UK|5',
    'Callahan|Laura|Inside Sales Coordinator|1958-01-09|1994-03-05|Seattle|USA|2',
    'Dodsworth|Anne|Sales Representative|1966-01-27|1994-11-15|London|UK|5');

  { tvrtka|kontakt|grad|drzava }
  Suppliers: array[1..12] of string = (
    'Exotic Liquids|Charlotte Cooper|London|UK',
    'New Orleans Cajun Delights|Shelley Burke|New Orleans|USA',
    'Grandma Kelly''s Homestead|Regina Murphy|Ann Arbor|USA',
    'Tokyo Traders|Yoshi Nagase|Tokyo|Japan',
    'Cooperativa de Quesos ''Las Cabras''|Antonio del Valle Saavedra|Oviedo|Spain',
    'Mayumi''s|Mayumi Ohno|Osaka|Japan',
    'Pavlova, Ltd.|Ian Devling|Melbourne|Australia',
    'Specialty Biscuits, Ltd.|Peter Wilson|Manchester|UK',
    'PB Knäckebröd AB|Lars Peterson|Göteborg|Sweden',
    'Heli Süßwaren GmbH & Co. KG|Petra Winkler|Berlin|Germany',
    'Plutzer Lebensmittelgroßmärkte AG|Martin Bein|Frankfurt|Germany',
    'Nord-Ost-Fisch Handelsgesellschaft mbH|Sven Petersen|Cuxhaven|Germany');

  { sifra|tvrtka|kontakt|grad|drzava }
  Customers: array[1..30] of string = (
    'ALFKI|Alfreds Futterkiste|Maria Anders|Berlin|Germany',
    'ANATR|Ana Trujillo Emparedados y helados|Ana Trujillo|México D.F.|Mexico',
    'ANTON|Antonio Moreno Taquería|Antonio Moreno|México D.F.|Mexico',
    'AROUT|Around the Horn|Thomas Hardy|London|UK',
    'BERGS|Berglunds snabbköp|Christina Berglund|Luleå|Sweden',
    'BLAUS|Blauer See Delikatessen|Hanna Moos|Mannheim|Germany',
    'BLONP|Blondesddsl père et fils|Frédérique Citeaux|Strasbourg|France',
    'BOLID|Bólido Comidas preparadas|Martín Sommer|Madrid|Spain',
    'BONAP|Bon app''|Laurence Lebihan|Marseille|France',
    'BOTTM|Bottom-Dollar Markets|Elizabeth Lincoln|Tsawassen|Canada',
    'BSBEV|B''s Beverages|Victoria Ashworth|London|UK',
    'CACTU|Cactus Comidas para llevar|Patricio Simpson|Buenos Aires|Argentina',
    'CENTC|Centro comercial Moctezuma|Francisco Chang|México D.F.|Mexico',
    'CHOPS|Chop-suey Chinese|Yang Wang|Bern|Switzerland',
    'COMMI|Comércio Mineiro|Pedro Afonso|São Paulo|Brazil',
    'CONSH|Consolidated Holdings|Elizabeth Brown|London|UK',
    'DRACD|Drachenblut Delikatessen|Sven Ottlieb|Aachen|Germany',
    'DUMON|Du monde entier|Janine Labrune|Nantes|France',
    'EASTC|Eastern Connection|Ann Devon|London|UK',
    'ERNSH|Ernst Handel|Roland Mendel|Graz|Austria',
    'FAMIA|Familia Arquibaldo|Aria Cruz|São Paulo|Brazil',
    'FISSA|FISSA Fabrica Inter. Salchichas S.A.|Diego Roel|Madrid|Spain',
    'FOLIG|Folies gourmandes|Martine Rancé|Lille|France',
    'FOLKO|Folk och fä HB|Maria Larsson|Bräcke|Sweden',
    'FRANK|Frankenversand|Peter Franken|München|Germany',
    'FRANR|France restauration|Carine Schmitt|Nantes|France',
    'FRANS|Franchi S.p.A.|Paolo Accorti|Torino|Italy',
    'FURIB|Furia Bacalhau e Frutos do Mar|Lino Rodriguez|Lisboa|Portugal',
    'GALED|Galería del gastrónomo|Eduardo Saavedra|Barcelona|Spain',
    'GODOS|Godos Cocina Típica|José Pedro Freyre|Sevilla|Spain');

  { naziv|kategorija|pakiranje|cijena|ukinut }
  Products: array[1..40] of string = (
    'Chai|1|10 boxes x 20 bags|18|0', 'Chang|1|24 - 12 oz bottles|19|0',
    'Aniseed Syrup|2|12 - 550 ml bottles|10|0', 'Chef Anton''s Cajun Seasoning|2|48 - 6 oz jars|22|0',
    'Chef Anton''s Gumbo Mix|2|36 boxes|21.35|1', 'Grandma''s Boysenberry Spread|2|12 - 8 oz jars|25|0',
    'Uncle Bob''s Organic Dried Pears|7|12 - 1 lb pkgs.|30|0', 'Northwoods Cranberry Sauce|2|12 - 12 oz jars|40|0',
    'Mishi Kobe Niku|6|18 - 500 g pkgs.|97|1', 'Ikura|8|12 - 200 ml jars|31|0',
    'Queso Cabrales|4|1 kg pkg.|21|0', 'Queso Manchego La Pastora|4|10 - 500 g pkgs.|38|0',
    'Konbu|8|2 kg box|6|0', 'Tofu|7|40 - 100 g pkgs.|23.25|0',
    'Genen Shouyu|2|24 - 250 ml bottles|15.5|0', 'Pavlova|3|32 - 500 g boxes|17.45|0',
    'Alice Mutton|6|20 - 1 kg tins|39|1', 'Carnarvon Tigers|8|16 kg pkg.|62.5|0',
    'Teatime Chocolate Biscuits|3|10 boxes x 12 pieces|9.2|0', 'Sir Rodney''s Marmalade|3|30 gift boxes|81|0',
    'Sir Rodney''s Scones|3|24 pkgs. x 4 pieces|10|0', 'Gustaf''s Knäckebröd|5|24 - 500 g pkgs.|21|0',
    'Tunnbröd|5|12 - 250 g pkgs.|9|0', 'Guaraná Fantástica|1|12 - 355 ml cans|4.5|1',
    'NuNuCa Nuß-Nougat-Creme|3|20 - 450 g glasses|14|0', 'Gumbär Gummibärchen|3|100 - 250 g bags|31.23|0',
    'Schoggi Schokolade|3|100 - 100 g pieces|43.9|0', 'Rössle Sauerkraut|7|25 - 825 g cans|45.6|1',
    'Thüringer Rostbratwurst|6|50 bags x 30 sausgs.|123.79|1', 'Nord-Ost Matjeshering|8|10 - 200 g glasses|25.89|0',
    'Gorgonzola Telino|4|12 - 100 g pkgs|12.5|0', 'Mascarpone Fabioli|4|24 - 200 g pkgs.|32|0',
    'Geitost|4|500 g|2.5|0', 'Sasquatch Ale|1|24 - 12 oz bottles|14|0',
    'Steeleye Stout|1|24 - 12 oz bottles|18|0', 'Inlagd Sill|8|24 - 250 g jars|19|0',
    'Gravad lax|8|12 - 500 g pkgs.|26|0', 'Côte de Blaye|1|12 - 75 cl bottles|263.5|0',
    'Chartreuse verte|1|750 cc per bottle|18|0', 'Boston Crab Meat|8|24 - 4 oz tins|18.4|0');

var
  Seed: Int64 = 20261103;

function Rnd(AMax: Integer): Integer;
begin
  Seed := (Seed * 1103515245 + 12345) mod 2147483648;
  Result := Integer((Seed shr 8) mod AMax);
end;

function Part(const S: string; AIndex: Integer): string;
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    L.Delimiter := '|';
    L.StrictDelimiter := True;
    L.QuoteChar := #0;
    L.DelimitedText := S;
    if AIndex < L.Count then Result := L[AIndex] else Result := '';
  finally
    L.Free;
  end;
end;

function Q(ADb: TAppDb; const S: string): string;
begin
  Result := ADb.QuoteLit(S);
end;

function IsoDate(ADt: TDateTime): string;
begin
  Result := FormatDateTime('yyyy"-"mm"-"dd', ADt);
end;

{ "CompanyName" -> "Company name" }
function CamelCaption(const AName: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(AName) do
  begin
    if (I > 1) and (AName[I] in ['A'..'Z']) and not (AName[I - 1] in ['A'..'Z']) then
      Result := Result + ' ' + LowerCase(AName[I])
    else
      Result := Result + AName[I];
  end;
  if (Length(Result) > 2) and (Copy(Result, Length(Result) - 1, 2) = 'ID') then
    Result := Copy(Result, 1, Length(Result) - 2) + ' ID';
end;

procedure CaptionAll(ADb: TAppDb);
var
  T: TStringList;
  I, J: Integer;
  M: TaFieldMeta;
  Ms: TFPObjectList;
begin
  T := ADb.UserTables;
  try
    for I := 0 to T.Count - 1 do
    begin
      Ms := ADb.LoadFieldMetas(T[I]);
      try
        for J := 0 to Ms.Count - 1 do
        begin
          M := TaFieldMeta(Ms[J]);
          M.Caption := CamelCaption(M.FieldName);
          ADb.SaveFieldMeta(M);
        end;
      finally
        Ms.Free;
      end;
    end;
  finally
    T.Free;
  end;
end;

function IfThenNull(const S: string): string;
begin
  if (S = '') or (S = '0') then Result := 'NULL' else Result := S;
end;

function ShippedSql(ADb: TAppDb; N: Integer; AOrdered: TDateTime): string;
begin
  if N > 205 then Result := 'NULL' else Result := Q(ADb, IsoDate(AOrdered + 2 + Rnd(10)));
end;

procedure MakeTables(ADb: TAppDb; ALog: TStrings);
begin
  EnsureTable(ADb, ALog, 'Categories', [
    'CategoryID|AutoNumber', 'CategoryName|Text|||R', 'Description|Memo']);
  EnsureTable(ADb, ALog, 'Suppliers', [
    'SupplierID|AutoNumber', 'CompanyName|Text|||R', 'ContactName|Text', 'ContactTitle|Text', 'Address|Text',
    'City|Text', 'Region|Text', 'PostalCode|Text', 'Country|Text', 'Phone|Text']);
  EnsureTable(ADb, ALog, 'Shippers', [
    'ShipperID|AutoNumber', 'CompanyName|Text|||R', 'Phone|Text']);
  EnsureTable(ADb, ALog, 'Customers', [
    'CustomerID|AutoNumber', 'CustomerCode|Text|||R', 'CompanyName|Text|||R', 'ContactName|Text', 'ContactTitle|Text',
    'Address|Text', 'City|Text', 'Region|Text', 'PostalCode|Text', 'Country|Text', 'Phone|Text']);
  EnsureTable(ADb, ALog, 'Employees', [
    'EmployeeID|AutoNumber', 'LastName|Text|||R', 'FirstName|Text|||R', 'Title|Text', 'BirthDate|Date', 'HireDate|Date',
    'Address|Text', 'City|Text', 'Region|Text', 'PostalCode|Text', 'Country|Text', 'HomePhone|Text',
    'ReportsTo|Integer||Employees.EmployeeID', 'Notes|Memo']);
  EnsureTable(ADb, ALog, 'Products', [
    'ProductID|AutoNumber', 'ProductName|Text|||R', 'SupplierID|Integer||Suppliers.SupplierID',
    'CategoryID|Integer||Categories.CategoryID', 'QuantityPerUnit|Text', 'UnitPrice|Currency|0',
    'UnitsInStock|Integer|0', 'UnitsOnOrder|Integer|0', 'ReorderLevel|Integer|0', 'Discontinued|YesNo|0']);
  EnsureTable(ADb, ALog, 'Orders', [
    'OrderID|AutoNumber', 'CustomerID|Integer||Customers.CustomerID', 'EmployeeID|Integer||Employees.EmployeeID',
    'OrderDate|Date|Today()', 'RequiredDate|Date', 'ShippedDate|Date', 'ShipVia|Integer||Shippers.ShipperID',
    'Freight|Currency|0', 'ShipName|Text', 'ShipAddress|Text', 'ShipCity|Text', 'ShipCountry|Text']);
  EnsureTable(ADb, ALog, 'OrderDetails', [
    'OrderDetailID|AutoNumber', 'OrderID|Integer||Orders.OrderID|RC', 'ProductID|Integer||Products.ProductID|R',
    'UnitPrice|Currency|0', 'Quantity|Integer|1', 'Discount|Decimal/2|0']);
  SetRule(ADb, 'OrderDetails', 'Quantity', '[Quantity] > 0', 'Količina mora biti veća od nule.');
  SetRule(ADb, 'OrderDetails', 'Discount', '([Discount] >= 0) And ([Discount] <= 1)', 'Popust je između 0 i 1 (npr. 0,15 = 15 %).');
  SetRule(ADb, 'Products', 'UnitPrice', '[UnitPrice] >= 0', 'Cijena ne može biti negativna.');
  SetRule(ADb, 'Orders', 'Freight', '[Freight] >= 0', 'Prijevoz ne može biti negativan.');
end;

procedure FillData(ADb: TAppDb; ALog: TStrings);
var
  I, J, N, Cust, Emp, Prod, Ship, Lines, K, OrdId: Integer;
  Base, OrdDate, ShipDate: TDateTime;
  Disc: array[0..5] of string;
  Used: array[1..40] of Boolean;
  Price: Double;
  Cn, Cc: string;
begin
  Disc[0] := '0'; Disc[1] := '0'; Disc[2] := '0.05'; Disc[3] := '0.1'; Disc[4] := '0.15'; Disc[5] := '0.2';
  ADb.Conn.StartTransaction;
  try
    for I := 1 to 8 do
      Exec(ADb, 'INSERT INTO Categories (CategoryID, CategoryName, Description) VALUES (' + IntToStr(I) + ', ' +
        Q(ADb, Part(Categories[I], 0)) + ', ' + Q(ADb, Part(Categories[I], 1)) + ')');
    for I := 1 to 12 do
      Exec(ADb, 'INSERT INTO Suppliers (SupplierID, CompanyName, ContactName, City, Country) VALUES (' + IntToStr(I) + ', ' +
        Q(ADb, Part(Suppliers[I], 0)) + ', ' + Q(ADb, Part(Suppliers[I], 1)) + ', ' + Q(ADb, Part(Suppliers[I], 2)) + ', ' +
        Q(ADb, Part(Suppliers[I], 3)) + ')');
    for I := 1 to 3 do
      Exec(ADb, 'INSERT INTO Shippers (ShipperID, CompanyName, Phone) VALUES (' + IntToStr(I) + ', ' +
        Q(ADb, Part(Shippers[I], 0)) + ', ' + Q(ADb, Part(Shippers[I], 1)) + ')');
    for I := 1 to 30 do
      Exec(ADb, 'INSERT INTO Customers (CustomerID, CustomerCode, CompanyName, ContactName, City, Country) VALUES (' +
        IntToStr(I) + ', ' + Q(ADb, Part(Customers[I], 0)) + ', ' + Q(ADb, Part(Customers[I], 1)) + ', ' +
        Q(ADb, Part(Customers[I], 2)) + ', ' + Q(ADb, Part(Customers[I], 3)) + ', ' + Q(ADb, Part(Customers[I], 4)) + ')');
    { nadredeni prvi, da strani kljuc bude zadovoljen }
    for K := 0 to 1 do
      for I := 1 to 9 do
        if (K = 0) = (Part(Employees[I], 7) = '0') then
          Exec(ADb, 'INSERT INTO Employees (EmployeeID, LastName, FirstName, Title, BirthDate, HireDate, City, Country, ReportsTo) VALUES (' +
            IntToStr(I) + ', ' + Q(ADb, Part(Employees[I], 0)) + ', ' + Q(ADb, Part(Employees[I], 1)) + ', ' +
            Q(ADb, Part(Employees[I], 2)) + ', ' + Q(ADb, Part(Employees[I], 3)) + ', ' + Q(ADb, Part(Employees[I], 4)) + ', ' +
            Q(ADb, Part(Employees[I], 5)) + ', ' + Q(ADb, Part(Employees[I], 6)) + ', ' +
            IfThenNull(Part(Employees[I], 7)) + ')');
    for I := 1 to 40 do
      Exec(ADb, 'INSERT INTO Products (ProductID, ProductName, SupplierID, CategoryID, QuantityPerUnit, UnitPrice, UnitsInStock, UnitsOnOrder, ReorderLevel, Discontinued) VALUES (' +
        IntToStr(I) + ', ' + Q(ADb, Part(Products[I], 0)) + ', ' + IntToStr((I - 1) mod 12 + 1) + ', ' + Part(Products[I], 1) + ', ' +
        Q(ADb, Part(Products[I], 2)) + ', ' + Part(Products[I], 3) + ', ' + IntToStr(5 + Rnd(120)) + ', ' + IntToStr(Rnd(4) * 10) + ', ' +
        IntToStr(Rnd(4) * 5) + ', ' + Part(Products[I], 4) + ')');
    { narudzbe i stavke }
    Base := EncodeDate(1996, 7, 4);
    for N := 1 to 220 do
    begin
      Cust := 1 + Rnd(30);
      Emp := 1 + Rnd(9);
      Ship := 1 + Rnd(3);
      OrdDate := Base + (N - 1) * 3 + Rnd(3);
      Cn := Part(Customers[Cust], 1);
      Cc := Part(Customers[Cust], 3);
      Exec(ADb, 'INSERT INTO Orders (OrderID, CustomerID, EmployeeID, OrderDate, RequiredDate, ShippedDate, ShipVia, Freight, ShipName, ShipCity, ShipCountry) VALUES (' +
        IntToStr(N) + ', ' + IntToStr(Cust) + ', ' + IntToStr(Emp) + ', ' + Q(ADb, IsoDate(OrdDate)) + ', ' + Q(ADb, IsoDate(OrdDate + 28)) + ', ' +
        ShippedSql(ADb, N, OrdDate) + ', ' + IntToStr(Ship) + ', ' + FloatToStr(2 + Rnd(19800) / 100, InvariantFS) + ', ' +
        Q(ADb, Cn) + ', ' + Q(ADb, Cc) + ', ' + Q(ADb, Part(Customers[Cust], 4)) + ')');
      OrdId := N;
      Lines := 1 + Rnd(4);
      FillChar(Used, SizeOf(Used), 0);
      for J := 1 to Lines do
      begin
        repeat Prod := 1 + Rnd(40); until not Used[Prod];
        Used[Prod] := True;
        Price := StrToFloat(Part(Products[Prod], 3), InvariantFS);
        Exec(ADb, 'INSERT INTO OrderDetails (OrderID, ProductID, UnitPrice, Quantity, Discount) VALUES (' + IntToStr(OrdId) + ', ' +
          IntToStr(Prod) + ', ' + FloatToStr(Price, InvariantFS) + ', ' + IntToStr(1 + Rnd(10) * 5) + ', ' + Disc[Rnd(6)] + ')');
      end;
    end;
    ADb.Conn.Commit;
  except
    ADb.Conn.Rollback;
    raise;
  end;
  ALog.Add('upisani podaci: 8 kategorija, 12 dobavljača, 3 pošiljatelja, 30 kupaca, 9 zaposlenika, 40 proizvoda, 220 narudžbi');
end;

procedure MakeQueries(ADb: TAppDb; ALog: TStrings);
begin
  SaveQuery(ADb, ALog, 'Current Product List',
    'SELECT ProductID, ProductName, UnitPrice, UnitsInStock FROM Products WHERE Discontinued = 0 ORDER BY ProductName');
  SaveQuery(ADb, ALog, 'Order Details Extended',
    'SELECT d.OrderID AS OrderID, d.ProductID AS ProductID, p.ProductName AS ProductName, d.UnitPrice AS UnitPrice,' + LineEnding +
    '       d.Quantity AS Quantity, d.Discount AS Discount,' + LineEnding +
    '       ROUND(d.UnitPrice * d.Quantity * (1 - d.Discount), 2) AS ExtendedPrice' + LineEnding +
    'FROM OrderDetails d JOIN Products p ON p.ProductID = d.ProductID ORDER BY d.OrderID, p.ProductName');
  SaveQuery(ADb, ALog, 'Order Subtotals',
    'SELECT OrderID, ROUND(SUM(UnitPrice * Quantity * (1 - Discount)), 2) AS Subtotal FROM OrderDetails GROUP BY OrderID');
  SaveQuery(ADb, ALog, 'Orders Qry',
    'SELECT o.OrderID AS OrderID, o.OrderDate AS OrderDate, o.ShippedDate AS ShippedDate, c.CompanyName AS Customer,' + LineEnding +
    '       c.Country AS Country, e.LastName || '' '' || e.FirstName AS Salesperson, s.CompanyName AS Shipper,' + LineEnding +
    '       o.Freight AS Freight, st.Subtotal AS Subtotal' + LineEnding +
    'FROM Orders o JOIN Customers c ON c.CustomerID = o.CustomerID JOIN Employees e ON e.EmployeeID = o.EmployeeID' + LineEnding +
    '     JOIN Shippers s ON s.ShipperID = o.ShipVia LEFT JOIN (SELECT OrderID, SUM(UnitPrice * Quantity * (1 - Discount)) AS Subtotal FROM OrderDetails GROUP BY OrderID) st ON st.OrderID = o.OrderID' + LineEnding +
    'ORDER BY o.OrderID');
  SaveQuery(ADb, ALog, 'Products by Category',
    'SELECT c.CategoryName AS CategoryName, p.ProductName AS ProductName, p.QuantityPerUnit AS QuantityPerUnit,' + LineEnding +
    '       p.UnitsInStock AS UnitsInStock, p.UnitPrice AS UnitPrice, p.Discontinued AS Discontinued' + LineEnding +
    'FROM Products p JOIN Categories c ON c.CategoryID = p.CategoryID ORDER BY c.CategoryName, p.ProductName');
  SaveQuery(ADb, ALog, 'Category Sales',
    'SELECT c.CategoryName AS CategoryName, strftime(''%Y'', o.OrderDate) AS SalesYear,' + LineEnding +
    '       ROUND(d.UnitPrice * d.Quantity * (1 - d.Discount), 2) AS Sales' + LineEnding +
    'FROM OrderDetails d JOIN Orders o ON o.OrderID = d.OrderID JOIN Products p ON p.ProductID = d.ProductID' + LineEnding +
    '     JOIN Categories c ON c.CategoryID = p.CategoryID');
  SaveQuery(ADb, ALog, 'Sales by Category',
    'SELECT CategoryName, SalesYear, ROUND(SUM(Sales), 2) AS TotalSales FROM (' +
    'SELECT c.CategoryName AS CategoryName, strftime(''%Y'', o.OrderDate) AS SalesYear, d.UnitPrice * d.Quantity * (1 - d.Discount) AS Sales ' +
    'FROM OrderDetails d JOIN Orders o ON o.OrderID = d.OrderID JOIN Products p ON p.ProductID = d.ProductID JOIN Categories c ON c.CategoryID = p.CategoryID) sq ' +
    'GROUP BY CategoryName, SalesYear ORDER BY CategoryName, SalesYear');
  SaveQuery(ADb, ALog, 'Sales by Customer',
    'SELECT c.CompanyName AS Customer, c.Country AS Country, COUNT(DISTINCT o.OrderID) AS Orders,' + LineEnding +
    '       ROUND(SUM(d.UnitPrice * d.Quantity * (1 - d.Discount)), 2) AS TotalSales' + LineEnding +
    'FROM Customers c JOIN Orders o ON o.CustomerID = c.CustomerID JOIN OrderDetails d ON d.OrderID = o.OrderID' + LineEnding +
    'GROUP BY c.CustomerID ORDER BY TotalSales DESC');
  SaveQuery(ADb, ALog, 'Sales by Employee',
    'SELECT e.LastName || '' '' || e.FirstName AS Salesperson, COUNT(DISTINCT o.OrderID) AS Orders,' + LineEnding +
    '       ROUND(SUM(d.UnitPrice * d.Quantity * (1 - d.Discount)), 2) AS TotalSales' + LineEnding +
    'FROM Employees e JOIN Orders o ON o.EmployeeID = e.EmployeeID JOIN OrderDetails d ON d.OrderID = o.OrderID' + LineEnding +
    'GROUP BY e.EmployeeID ORDER BY TotalSales DESC');
  SaveQuery(ADb, ALog, 'Products Above Average Price',
    'SELECT ProductName, UnitPrice FROM Products WHERE UnitPrice > (SELECT AVG(UnitPrice) FROM Products) ORDER BY UnitPrice DESC');
  SaveQuery(ADb, ALog, 'Orders in Date Range',
    'SELECT o.OrderID AS OrderID, o.OrderDate AS OrderDate, c.CompanyName AS Customer, o.Freight AS Freight' + LineEnding +
    'FROM Orders o JOIN Customers c ON c.CustomerID = o.CustomerID' + LineEnding +
    'WHERE o.OrderDate >= [?Od datuma] AND o.OrderDate <= [?Do datuma] ORDER BY o.OrderDate');
  SaveQuery(ADb, ALog, 'Unshipped Orders',
    'SELECT o.OrderID AS OrderID, o.OrderDate AS OrderDate, c.CompanyName AS Customer FROM Orders o JOIN Customers c ON c.CustomerID = o.CustomerID WHERE o.ShippedDate IS NULL ORDER BY o.OrderDate');
end;

procedure MakeCrosstab(ADb: TAppDb; ALog: TStrings);
var
  Sql, Err: string;
begin
  if BuildCrosstabSql(ADb, 'Category Sales', 'CategoryName', 'SalesYear', 'Sales', caSum, True, Sql, Err) then
    SaveQuery(ADb, ALog, 'Category Sales by Year (crosstab)', Sql)
  else
    ALog.Add('crosstab nije izrađen: ' + Err);
end;

procedure MakeForms(ADb: TAppDb; ALog: TStrings);
var
  Fo: TaFormOptions;
  Fl, Subs: TStringList;
  Def: TaFormDef;
  M: TaMDMulti;
  Mr: TaMDMultiResult;
  Mf, Df: TStringList;
  I: Integer;
  C: TaControlDef;
  Doc: TaFormDef;

  procedure Simple(const ATable, AName, ATitle: string; ALayout: TaFormLayout);
  begin
    Fo.Source := ATable; Fo.Name := AName; Fo.Title := ATitle; Fo.Fields := nil; Fo.Layout := ALayout; Fo.SubTables := nil;
    Fl := TStringList.Create;
    try
      Fo.Fields := Fl;
      Def := BuildFormEx(ADb, Fo);
    finally
      Fl.Free;
    end;
    SaveForm(ADb, ALog, Def);
  end;

begin
  Simple('Categories', 'Categories', 'Categories', flOneColumn);
  Simple('Suppliers', 'Suppliers', 'Suppliers', flTwoColumns);
  Simple('Shippers', 'Shippers', 'Shippers', flOneColumn);
  Simple('Employees', 'Employees', 'Employees', flTwoColumns);
  Simple('Products', 'Products', 'Products', flTwoColumns);
  Simple('Products', 'Products List', 'Products List', flDatasheet);
  Simple('Customers', 'Customers List', 'Customers List', flDatasheet);
  { Customers s podformom narudzbi }
  Subs := TStringList.Create;
  Fl := TStringList.Create;
  try
    Subs.Add('Orders');
    Fo.Source := 'Customers'; Fo.Name := 'Customers'; Fo.Title := 'Customers'; Fo.Fields := Fl; Fo.Layout := flTwoColumns; Fo.SubTables := Subs;
    SaveForm(ADb, ALog, BuildFormEx(ADb, Fo));
  finally
    Fl.Free;
    Subs.Free;
  end;
  { Orders: master-detail s izracunom stavki i ukupnim iznosom }
  Mf := TStringList.Create;
  Df := TStringList.Create;
  try
    Mf.CommaText := 'OrderID,CustomerID,EmployeeID,OrderDate,RequiredDate,ShippedDate,ShipVia,Freight';
    Df.CommaText := 'ProductID,UnitPrice,Quantity,Discount';
    M.Master := 'Orders'; M.Name := 'Orders'; M.Title := 'Orders'; M.MasterFields := Mf;
    SetLength(M.Details, 1);
    M.Details[0].Table := 'OrderDetails'; M.Details[0].Fields := Df; M.Details[0].SumField := ''; M.Details[0].ShowCount := True;
    M.Details[0].FkCol := ''; M.Details[0].ParentCol := '';
    M.DetailAsForm := False; M.UseTabs := False;
    Mr := BuildMasterDetailMulti(ADb, M);
    if Mr.Error <> '' then ALog.Add('Orders: ' + Mr.Error)
    else
    begin
      Doc := Mr.MasterForm;
      for I := 0 to Doc.Count - 1 do
        if Doc[I].Kind = 'Subform' then
        begin
          Doc[I].SetX('calc', 'Extended=[UnitPrice] * [Quantity] * (1 - [Discount])');
          Doc[I].SetX('autofill', 'ProductID>Products.ProductID:UnitPrice=UnitPrice');
        end;
      C := TaControlDef.Create;
      C.Kind := 'Label'; C.Name := Doc.UniqueName('lblTotal'); C.Caption := 'Order total:'; C.Bold := True;
      C.Left := 16; C.Top := Doc.Height - 40; C.Width := 100; C.Height := 22;
      Doc.Add(C);
      C := TaControlDef.Create;
      C.Kind := 'TextBox'; C.Name := Doc.UniqueName('txtTotal');
      C.ControlSource := '=Nz(DSum("UnitPrice * Quantity * (1 - Discount)", "OrderDetails", "OrderID = " & [OrderID]), 0) + Nz([Freight], 0)';
      C.Format := '#,##0.00';
      C.Bold := True;
      C.Left := 120; C.Top := Doc.Height - 42; C.Width := 140; C.Height := 24;
      Doc.Add(C);
      SaveForm(ADb, ALog, Doc);
      for I := 0 to High(Mr.Items) do
      begin
        if Mr.Items[I].QueryName <> '' then ADb.SaveObject('_sys_queries', Mr.Items[I].QueryName, Mr.Items[I].QuerySql);
        if Mr.Items[I].Form <> nil then SaveForm(ADb, ALog, Mr.Items[I].Form);
      end;
    end;
  finally
    Mf.Free;
    Df.Free;
  end;
  { proizvodi koji su ukinuti prikazuju se sivo }
  Def := TaFormDef.Create;
  try
    Def.FromJson(ADb.LoadObject('_sys_forms', 'Products List'));
    Def.Name := 'Products List';
    Def.GridFormat := '[Discontinued] => #808080 #F0F0F0';
    ADb.SaveObject('_sys_forms', 'Products List', Def.ToJson);
  finally
    Def.Free;
  end;
end;

procedure MakeReports(ADb: TAppDb; ALog: TStrings);
var
  Ro: TaReportOptions;
  Fl, Ll, Mf, Df: TStringList;
  O: TaMDOptions;
  Rr: TaMDReportResult;
begin
  Fl := TStringList.Create;
  Ll := TStringList.Create;
  try
    Fl.CommaText := 'ProductName,QuantityPerUnit,UnitsInStock,UnitPrice';
    Ro.Source := 'Products by Category'; Ro.Name := 'Products by Category'; Ro.Title := 'Products by Category';
    Ro.GroupField := 'CategoryName'; Ro.SortField := ''; Ro.Fields := Fl; Ro.Kind := rkTabular;
    Ro.Descending := False; Ro.Sums := False; Ro.PageBreakPerRecord := False; Ro.LabelColumns := 3; Ro.LabelLines := nil;
    SaveReport(ADb, ALog, BuildReportEx(ADb, Ro));
    Fl.CommaText := 'Customer,Country,Orders,TotalSales';
    Ro.Source := 'Sales by Customer'; Ro.Name := 'Sales by Customer'; Ro.Title := 'Sales by Customer';
    Ro.GroupField := ''; Ro.Fields := Fl; Ro.Sums := True;
    SaveReport(ADb, ALog, BuildReportEx(ADb, Ro));
    Fl.CommaText := 'CategoryName,SalesYear,TotalSales';
    Ro.Source := 'Sales by Category'; Ro.Name := 'Sales by Category'; Ro.Title := 'Sales by Category';
    Ro.GroupField := 'CategoryName'; Ro.Fields := Fl; Ro.Sums := True;
    SaveReport(ADb, ALog, BuildReportEx(ADb, Ro));
    Fl.CommaText := 'Salesperson,Orders,TotalSales';
    Ro.Source := 'Sales by Employee'; Ro.Name := 'Sales by Employee'; Ro.Title := 'Sales by Employee';
    Ro.GroupField := ''; Ro.Fields := Fl; Ro.Sums := True;
    SaveReport(ADb, ALog, BuildReportEx(ADb, Ro));
    { naljepnice kupaca }
    Fl.CommaText := 'CompanyName';
    Ll.Add('[CompanyName]'); Ll.Add('[ContactName]'); Ll.Add('[City] & ", " & [Country]');
    Ro.Source := 'Customers'; Ro.Name := 'Customer Labels'; Ro.Title := ''; Ro.GroupField := ''; Ro.SortField := 'CompanyName';
    Ro.Fields := Fl; Ro.Kind := rkLabels; Ro.Sums := False; Ro.LabelColumns := 3; Ro.LabelLines := Ll;
    SaveReport(ADb, ALog, BuildReportEx(ADb, Ro));
  finally
    Fl.Free;
    Ll.Free;
  end;
  { Invoice: narudzba i njezine stavke }
  Mf := TStringList.Create;
  Df := TStringList.Create;
  try
    Mf.CommaText := 'OrderID,OrderDate,ShippedDate,Customer,Country,Salesperson,Shipper,Freight';
    Df.CommaText := 'ProductName,UnitPrice,Quantity,Discount,ExtendedPrice';
    O.Master := 'Orders Qry'; O.Detail := 'Order Details Extended'; O.Name := 'Invoice'; O.Title := 'Invoice';
    O.MasterFields := Mf; O.DetailFields := Df; O.DetailAsForm := False; O.SumField := 'ExtendedPrice'; O.ShowCount := False;
    O.FkCol := 'OrderID'; O.ParentCol := 'OrderID';
    Rr := BuildMasterDetailReport(ADb, O);
    if Rr.Error <> '' then ALog.Add('Invoice: ' + Rr.Error)
    else
    begin
      ADb.SaveObject('_sys_queries', Rr.QueryName, Rr.QuerySql);
      ADb.SaveObject('_sys_reports', 'Invoice', Rr.Def.ToJson);
      Rr.Def.Free;
      ALog.Add('izrađeno izvješće Invoice');
    end;
  finally
    Mf.Free;
    Df.Free;
  end;
end;

function BuildNorthwind(ADb: TAppDb; ALog: TStrings): Boolean;
var
  S: TaAppSettings;
begin
  Result := True;
  try
    MakeTables(ADb, ALog);
    FillData(ADb, ALog);
    CaptionAll(ADb);
    ALog.Add('rječnik podataka: oznake polja postavljene');
    MakeQueries(ADb, ALog);
    MakeCrosstab(ADb, ALog);
    MakeForms(ADb, ALog);
    MakeReports(ADb, ALog);
    { revizijski trag na najvaznijim tablicama }
    AuditEnable(ADb, 'Customers');
    AuditEnable(ADb, 'Products');
    AuditEnable(ADb, 'Orders');
    ALog.Add('revizijski trag uključen na Customers, Products i Orders');
    BuildAppSwitchboard(ADb, ALog);
    S := LoadAppSettings(ADb);
    S.Title := 'Northwind Traders';
    SaveAppSettings(ADb, S);
    ALog.Add('naslov aplikacije: Northwind Traders');
  except
    on E: Exception do
    begin
      ALog.Add('GREŠKA: ' + E.Message);
      Result := False;
    end;
  end;
end;

end.
