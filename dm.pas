unit DM;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqlite3conn, sqldb, db, contnrs {for TObjectList};

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
    function GetLastRowId : integer;
    //-- users
    function CheckUser(login,password:string) : integer; // res > 0 - OK;  -1 - wrong login/password; -999 - DB not connected
    //-- blocks
    procedure BlocksOpen;
    function GetBlocksFromTmp(tmpid:integer): TObjectList;
    procedure FillBlockNames(var OutBlocks : TStrings;temp_id : integer = -1);
    //-- projects
    function AddProject(Info: string='') : integer;
    function GetProject(prid : integer) : boolean;
    function GetProjectFields:boolean;
    //-- templates
    function GetTemplatesOfProject(prjid:integer):TObjectList;
    function InsertTemplate(prj_id: integer; TempName,FName: string):integer;
  end;

var
  DM1: TDM1;

implementation

{$R *.lfm}

uses MainForm, CommonUnit, StrUtils, md5 ;


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

function TDM1.GetLastRowId : integer;
begin
  Result := -1;
  with SQLQuery1 do
  try
    Close;
    SQL.Text:='SELECT last_insert_rowid() as LIR';
    try
      Open;
      if RecordCount<1 then raise Exception.Create('unable get last inserted rowid');
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

function TDM1.GetBlocksFromTmp(tmpid:integer): TObjectList;
var
  b : TBlock;
begin
  Result := nil;
  if tmpid<=0 then Exit;
  with SQLQuery1 do
  try
    Close;
    Params.Clear;
    SQL.Text:='SELECT * FROM blocks WHERE tmp_id=:tmpid;';
    ParamByName('tmpid').AsInteger:=tmpid;
    try
      Open;
      if RecordCount<1 then Exit;
      First;
      Result := TObjectList.Create;
      while not EOF do
      begin
        b := TBlock.Create;
        b.SetBlockData(
          FieldByName('id').AsInteger,
          FieldByName('blockorder').AsInteger,
          FieldByName('blockname').AsString,
          FieldByName('blockinfo').AsString
        );
        Result.Add(b);
        Next;
      end;
    except
      raise Exception.Create('Ошибка формирования списка блоков');
      if Assigned(Result) then Result.Free;
    end;
  finally
    Close;
  end;
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
  //TODO:  SQLite3 only (twin operation: insert + get last row id) !!!!
  If IsEmptyStr(Info,[' ']) then Info := 'Project ('+DateToStr(now)+')';
  with SQLQuery1 do
  begin
    Close;
    SQL.Clear;
    SQL.Text := 'INSERT INTO projects (prjname, prjcreated, prjmodified,prjinfo, user_id) VALUES (:prj_name,CURRENT_DATE,CURRENT_DATE,:info, :userid);';
    SQLQuery1.ParamByName('prj_name').AsString:=MD5Print(MD5String(Info));
    SQLQuery1.ParamByName('info').AsString:=Info;
    SQLQuery1.ParamByName('userid').AsInteger:=MainForm1.CurrentUser.id;
    try
      ExecSQL;
      if SQLTransaction.Active then SQLTransaction.Commit;
      Result := GetLastRowId;
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
      SQLQuery1.FieldByName('prjcreated').AsDateTime,
      SQLQuery1.FieldByName('prjmodified').AsDateTime,
      SQLQuery1.FieldByName('prjinfo').AsString,
      SQLQuery1.FieldByName('lentmp').AsInteger>0  //TODO: >length('{<Block>}') - ?
    );
    Result := True;
  except
    Result := False;
  end;
end;

function TDM1.InsertTemplate(prj_id: integer; TempName,FName: string):integer;
begin
  Result := -1;
  if (prj_id<=0) or not FileExists(FName) then Exit;
  SQLQuery1.Close;
  SQLQuery1.SQL.Text:='INSERT INTO templates (prj_id,tmpname,tmp) VALUES(:prjid,:tempname,:tmpfile);';
  SQLQuery1.ParamByName('prjid').AsInteger := prj_id;
  SQLQuery1.ParamByName('tempname').AsString := TempName;
  try
    SQLQuery1.ParamByName('tmpfile').LoadFromFile(FName,ftBlob);
    SQLQuery1.ExecSQL;
    Result := GetLastRowId;
  finally
    SQLQuery1.Close;
  end;
end;

function TDM1.GetTemplatesOfProject(prjid:integer):TObjectList;
var
  t : TTemplate;
begin
  Result := nil;
  if prjid<=0 then Exit;
  with SQLQuery1 do
  try
    Close;
    Params.Clear;
    SQL.Text:='SELECT t.id,t.tmpname,t.uid, length(t.tmp) as len FROM templates t WHERE prj_id=:prjid;';
    ParamByName('prjid').AsInteger:=prjid;
    try
      Open;
      if RecordCount<1 then Exit;
      First;
      Result := TObjectList.Create;
      while not EOF do
      begin
        t := TTemplate.Create;
        t.SetTmp(
          FieldByName('id').AsInteger,
          FieldByName('tmpname').AsString,
          FieldByName('uid').AsString
          // ,FieldByName('len').AsInteger
        );
        Result.Add(t);
        Next;
      end;
    except
      raise Exception.Create('Ошибка формирования списка шаблонов');
      if Assigned(Result) then Result.Free;
    end;
  finally
    Close;
  end;
end;

{
aMStr:TMemoryStream;
aField:TBlobField;
begin
   aMStr:TMemoryStream.Create;
   try
      aField:=(MyQuery.FieldByName('IMG_FIELD_NAME')) as TBlobField);
      aField.SaveToStream(aMStr);
      aMStr.Position:=0;
      MyImage1.Picture.LoadFromStream(aMStr); //если копируем на имэйдж на форме
   finally
      aMStr.free;
   end;
end;
-------------------------




Не вижу проблемы вытащить из базы:

    qTasksPAYLOAD: TOraMemoField; { TMemoField, TBlobField, ... }
....
        if qTasksPAYLOAD.BlobSize > 0 then
        begin
          Context.TaskStream := TMemoryStream.Create;
          Context.TaskStream.Size := qTasksPAYLOAD.BlobSize;
          qTasksPAYLOAD.SaveToStream(Context.TaskStream);
        end
        else
          Context.TaskStream := nil;



Поместить в базу еще проще:

  qTasksPAYLOAD.LoadFromStream (Context.TaskStream);



далее стандартные операции TDataSet

----
Чтение

      LStrm := TIBBlobStream.Create;
      try
        LStrm.Mode := bmRead;
        LStrm.Database := ADS.Database;
        LStrm.Transaction := ADS.Transaction;
        LStrm.BlobID := AField.AsQuad;
        LStrm.ReadBuffer(.........);
      finally
        LStrm.Free;
      end;

Запись

      LStrm := TIBBlobStream.Create;
      try
        LStrm.Mode := bmWrite;
        LStrm.Database := ADS.Database;
        LStrm.Transaction := ADS.Transaction;
        LStrm.WriteBuffer(.......);
        LStrm.Finalize;
        AField.AsQuad := LStrm.BlobID;
      finally
        LStrm.Free;
      end;

-----
Ну, загрузи эти данные из базы в память да передай в нить адрес начала блока и его длину.
Например, с помощью TMemoryStream.

var
  fQ_IBX : TIBSQL; // IBX
  fQ_FIB : TpFIBQuery; // FIB+

  fMS : TMemoryStream;
begin
  fMS := TMemoryStream.Create;
...
  fQ_IBX.FieldByName('blob_field_1').SaveToStream(fMS);
...
  fQ_FIB.FieldByName('blob_field_2').SaveToStream(fMS);


И передавай в нить этот самый fMS.

Если блок данных очень уж велик, то сохраняй в файл:

var
  fQ_IBX : TIBSQL; // IBX
  fQ_FIB : TpFIBQuery; // FIB+

  fFS : TFileStream;
begin
  fFS := TFileStream.Create(<имя временного файла>, fmCreate);
...
  fQ_IBX.FieldByName('blob_field_1').SaveToStream(fFS);
...
  fQ_FIB.FieldByName('blob_field_2').SaveToStream(fFS);


... или даже в файл, который будет автоматически удаляться, кода он станет не нужным:

var
  fH : Handle;
begin
  fH := CreateFile(<имя временного файла>, GENERIC_READ or GENERIC_WRITE, 0, nil, CREATE_ALWAYS, FILE_ATTRIBUTE_TEMPORARY or FILE_FLAG_DELETE_ON_CLOSE, 0);
  fFS := TFileStream.Create(fH);


... а то и просто хэндл файла передавай.

----------------------------------------------------
---- threads:
{ TMyThread }

procedure TMyThread.Execute;
var
  msg: TLMessage;
begin
  msg.wParam:= FArrStreamRec[0].ContainerType;
  SendMessage(Form1.Handle,WM_CONTAINERCLEAR_MSG,msg.wParam,0);//чистим контейнер (это memo)
  SendMessage(Form1.Handle,WM_ADDSTREAMPARAM_MSG,0,DWORD(@FArrStreamRec[0]));
  Sleep(2000);

  msg.wParam:= FArrStreamRec[1].ContainerType;
  SendMessage(Form1.Handle,WM_CONTAINERCLEAR_MSG,msg.wParam,0);//чистим контейнер (это Picture)
  SendMessage(Form1.Handle,WM_ADDSTREAMPARAM_MSG,0,DWORD(@FArrStreamRec[1]));
  Sleep(2000);

  FIsTermThread:= True;
end;

----------------------

//--- SQLite Create Blob in DB;

uses
  SQLite3, SQLite3Wrap, Classes, Sysutils;
const
  CountryNames: array[1..5] of string = ('Argentina', 'Australia', 'Austria', 'Belgium', 'Botswana');
var
  DB: TSQLite3Database;
  Stmt: TSQLite3Statement;
  Stream: TMemoryStream;
  i: Integer;
begin
  DB := TSQLite3Database.Create;
  DB.Open('Countries.sqlite');
  DB.Execute('CREATE TABLE Flags (Country VARCHAR(15) PRIMARY KEY, Flag BLOB)');
  for i := 1 to 5 do
    begin
      Stmt := DB.Prepare('INSERT INTO Flags VALUES (' + quotedStr(CountryNames[i]) + ',?)');
      Stream := TMemoryStream.Create;
      Stream.LoadFromFile(CountryNames[i] + '.png');
      Stmt.BindBlob(1, Stream.Memory, Stream.Size);
      Stream.Free;
      Stmt.Step;
    end;
  Stmt.Free;
end.
}

end.

