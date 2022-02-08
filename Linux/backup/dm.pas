unit DM;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqlite3conn, sqldb, db;

type

  { TDM1 }

  TDM1 = class(TDataModule)
    DataSource1: TDataSource;
    SQLite3Connection1: TSQLite3Connection;
    SQLQuery1: TSQLQuery;
    SQLTransaction1: TSQLTransaction;
  private

  public
    function DBConnect : boolean;
    function CheckUser(login,password:string) : integer; // res > 0 - OK;  -1 - wrong login/password; -999 - DB not connected
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

end.

