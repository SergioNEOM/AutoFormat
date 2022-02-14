unit DM;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqlite3conn, sqldb, db;

const
  SQL_BLOCKS = 'SELECT * FROM blocks WHERE tmp_id=:tmpid;';

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
    //-- users
    function CheckUser(login,password:string) : integer; // res > 0 - OK;  -1 - wrong login/password; -999 - DB not connected
    //-- blocks
    procedure BlocksOpen;
    procedure FillBlockNames(var OutBlocks : TStrings;temp_id : integer = -1);
    //-- projects
    function AddProject(Info: string='') : integer;
    function GetProject(prid : integer) : boolean;
    function GetProjectFields:boolean;
  end;

var
  DM1: TDM1;

implementation

{$R *.lfm}

uses MainForm, CommonUnit;


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

procedure TDM1.FillBlockNames(var OutBlocks : TStrings;temp_id : integer = -1);
var
  b :  TBlock; // CommonUnit.TBlock
  Res : TStrings;
begin
  Res := nil;
  if temp_id <=0 then Exit;
  //
  try
    Res := TStrings.Create;
    b := TBlock.Create;
  except
    Exit;
  end;
  with Blocks do
  begin
    Close;
    Params.Clear;
    SQL.Text:=SQL_BLOCKS;
    ParamByName('tmpid').Value:=temp_id;
    try
      try
        Open;
        First;
        while not EOF do
        begin
          b.SetBlockData(
            FieldByName('id').AsInteger,
            FieldByName('blockorder').AsInteger,
            FieldByName('blockname').AsString,
            FieldByName('blockinfo').AsString
          );
          Res.AddObject(FieldByName('blockname').AsString, b);
          Next;
        end;
      except
        //TODO: ???
      end;
    finally
      Close;
    end;
  end;
end;

function TDM1.AddProject(Info: string='') : integer;
begin
  Result := -1;
  //TODO:  SQLite3 only (twin operation) !!!!
  with SQLQuery1 do
  begin
    Close;
    SQL.Clear;
    SQL.Text := 'INSERT INTO projects (prjdate,prjinfo) VALUES (CURRENT_DATE,:info);';
    SQLQuery1.ParamByName('info').AsString:=Info;
    try
      ExecSQL;
      if SQLTransaction.Active then SQLTransaction.Commit;
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
      Close;
    end;
  end;

  //TODO:  if PostgreSQL need use 'INSERT ... RETURNING id'  in one query!!!
end;

function TDM1.GetProject(prid : integer) : boolean;
begin
  Result := False;
  if prid <= 0 then Exit;
  with SQLQuery1 do
  try
    Close;
    //TODO: SQLite SQL script !!
    SQL.Text:='SELECT p.id,p.prjdate,p.prjinfo,length(t.tmp) as lentmp FROM projects p, templates t WHERE p.tmp_id=t.id and p.id=:prid;';
    ParamByName('prid').AsInteger:=prid;
    try
      Open;
      if RecordCount<1 then Exit;
      First;
      Result := GetProjectFields;
    except
      Exit;
    end;
  finally
    Close;
  end;
end;

function TDM1.GetProjectFields : boolean;
begin
  try
    MainForm1.CurrentProject.SetPrj(
      SQLQuery1.FieldByName('id').AsInteger,
      SQLQuery1.FieldByName('prjdate').AsDateTime,
      SQLQuery1.FieldByName('prjinfo').AsString,
      SQLQuery1.FieldByName('lentmp').AsInteger>0  //TODO: >length('{<Block>}') - ?
    );
    Result := True;
  except
    Result := False;
  end;
end;

end.

