unit DM;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqlite3conn, sqldb, db;

type

  { TDM1 }

  TDM1 = class(TDataModule)
    DataSource1: TDataSource;
    Blocks_DS: TDataSource;
    SQLite3Connection1: TSQLite3Connection;
    SQLQuery1: TSQLQuery;
    Blocks: TSQLQuery;
    SQLScript1: TSQLScript;
    SQLTransaction1: TSQLTransaction;
    TranScript: TSQLTransaction;
    SQLTransaction3: TSQLTransaction;
    SQLTransactionMain: TSQLTransaction;
  private

  public
    function DBConnect : boolean;
    function CheckUser(login,password:string) : integer; // res > 0 - OK;  -1 - wrong login/password; -999 - DB not connected
    procedure BlocksOpen;
    function FillBlockNames: TStrings;
    function AddProject : integer;
  end;

var
  DM1: TDM1;

implementation

{$R *.lfm}

uses MainForm;


function TDM1.DBConnect : boolean;
begin
  SQLite3Connection1.DatabaseName:= MainForm1.DBFile;
  try
    SQLite3Connection1.Connected:=True;
    Result := True;
  except
    SQLite3Connection1.Connected:=False;
    Result := False;
  end;
end;

function TDM1.CheckUser(login,password:string): integer;
begin
  Result := -1;
  if not SQLite3Connection1.Connected then
  begin
    Result := -999;
    Exit;
  end;
  with SQLQuery1 do
  begin
    Close;
    sql.Text:='SELECT id,username,superuser,password FROM users WHERE login=:lo';
    ParamByName('lo').Value:=login;
    try
      try
        Open;
        if IsEmpty then raise Exception.Create('user not found');
        if FieldByName('password').AsString <> password then raise Exception.Create('wrong password');
        Result := FieldByName('id').AsInteger;
        MainForm1.CurrentUser.id:= Result;
        MainForm1.CurrentUser.name:= FieldByName('username').AsString;
        MainForm1.CurrentUser.super:= FieldByName('superuser').AsString='*';
        // OK
      except
        Exit;
      end;
    finally
      Close;
    end;
  end;
end;

procedure TDM1.BlocksOpen;
begin
{  if MainForm1.CurrentUser.id <= 0 then Exit;
  with Blocks do
  begin
    Close;
    SQL.Text:='SELECT * FROM blocks ORDER BY blockorder';
  end;
}
end;

function TDM1.FillBlockNames: TStrings;
begin
  Result := TStrings.Create;
end;

function TDM1.AddProject : integer;
begin
  Result := -1;
  //TODO:  SQLite3 only (twin operation) !!!!
  SQLScript1.Script.Clear;
  SQLScript1.Script.Add('INSERT INTO projects (prjdate) VALUES (CURRENT_DATE);');
  try
    if not TranScript.Active then TranScript.StartTransaction;
    SQLScript1.Execute;
    if TranScript.Active then TranScript.Commit;
    with SQLQuery1 do
    try
      Close;
      SQL.Text:='SELECT last_insert_rowid() as LIR';
      try
        Open;
        if RecordCount<1 then raise Exception.Create('unable get lastinsert rowid');
        First;
        Result := Fields[0].AsInteger;
      except
        if SQLTransaction1.Active then SQLTransaction1.Rollback;
        Exit;
      end;
    finally
      if SQLTransaction1.Active then SQLTransaction1.Rollback;
      Close;
    end;
  except
    if TranScript.Active then TranScript.Rollback;
    Exit;
  end;

  //TODO:  if PostgreSQL need use 'INSERT ... RETURNING id'  in one query!!!
end;

end.

