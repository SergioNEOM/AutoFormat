unit DM;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqlite3conn, sqldb, db, contnrs {for TObjectList} ;

const
  SQL_BLOCKS = 'SELECT * FROM blocks WHERE tmp_id=:tmpid;';

type

  { TDM1 }

  TDM1 = class(TDataModule)
    Blocks: TSQLQuery;
    Content: TSQLQuery;
    Blocks_DS: TDataSource;
    Content_DS: TDataSource;
    CurrentUser: TSQLQuery;
    Projects_DS: TDataSource;
    DataSource1: TDataSource;
    Users: TSQLQuery;
    CU_DS: TDataSource;
    Temp_DS: TDataSource;
    SQLite3Connection1: TSQLite3Connection;
    SQLQuery1: TSQLQuery;
    Templates: TSQLQuery;
    Projects: TSQLQuery;
    SQLScript1: TSQLScript;
    TranScript: TSQLTransaction;
    SQLTransactionMain: TSQLTransaction;
    Users_DS: TDataSource;
  private

  public
    function DBConnect : boolean;
    function GetLastRowId : integer;
    //-- CurrentUser
    function CheckUser(login,password:string) : integer; // res > 0 - OK;  -1 - wrong login/password; -999 - DB not connected
    function GetCurrentUserId:integer;
    function GetCurrentUserRole:integer;
    function GetCurrentUserName:string;
    function AddUser(login, pass, username: string; admin: string=''):integer;
    function UpdUser(uid: integer; login, pass, username: string; admin: string=''):boolean;
    function DelUser(user_id:integer=-1):boolean;
    function UserIsAdmin(user_id:integer=-1):boolean;
    function AdminsCount:integer;
    //-- projects
    procedure RefreshProjects(role: integer);
    function AddProject(Info: string='') : integer;
    function GetCurrentProjectId : integer;
    function GetCurrentProjectInfo : string;
    function GetProject(prid : integer) : boolean;
    function DelProject : boolean;
    //function GetProjectFields:boolean;
    //-- blocks
    procedure BlocksOpen;
    function GetCurrentBlockId : integer;
    function GetBlocksFromTmp(tmpid:integer): TObjectList;
    procedure FillBlockNames(var OutBlocks : TStrings;temp_id : integer = -1);
   // function AddBlock2DB(blk : TBlock):integer;
    function AddBlk2DB(temp_id: integer; blk: string; blord:integer=0):integer;
    function insertBlocks2DB(blks : TObjectList {list of TBlock}; temp_id : integer = -1):boolean;
  // function UpdBlockInDB(blk : TBlock; temp_id : integer = -1):boolean;
    function SaveBlocks2DB(blks : TObjectList {list of TBlock}; temp_id : integer = -1):boolean;
    function SaveBlockInfo(bid:integer=-1; binfo:string=''):boolean;
    //-- templates
    function GetCurrentTemplateId : integer;
    function GetCurrentTempName:string;
    function GetTemplatesOfProject(prjid:integer):TObjectList;
    function AddTemplate(prj_id: integer; TempName,FName: string):integer;
    function DelTemplate(tmp_id:integer=-1):boolean;
    //-- content
    //function GetCurrentContentId:integer;
    procedure OpenContent(uid, bid : integer);
    procedure CloseContent;
    function GetContentId(uid, bid : integer):integer;
    function GetContentText(cid: integer):string;
    function AddContent2DB(uid, bid : integer; cont:string=''; UpdateIfExist:boolean=False):integer;
    function UpdContent(cid: integer; cont:string=''):boolean;
  end;

var
  DM1: TDM1;

implementation

{$R *.lfm}

uses MainForm,  StrUtils, CommonUnit ;


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
      if SQLTransaction.Active then SQLTransaction.Rollback;
      Exit;
    end;
  finally
    Close;
  end;
end;

{CurrentUser}
function TDM1.CheckUser(login,password:string): integer;
begin
  Result := -1;
  password  := HashPass(password);
  if not SQLite3Connection1.Connected then
  begin
    Result := -999;
    Exit;
  end;
  with CurrentUser do
  begin
    Close;
    sql.Text:='SELECT id,username,superuser,password FROM users WHERE login=:lo';
    ParamByName('lo').Value:=login;
    try
      Open;
      if IsEmpty then raise Exception.Create('user not found');
      if FieldByName('password').AsString <> password then raise Exception.Create('wrong password'); //TODO: debug log
      Result := FieldByName('id').AsInteger;
      // OK
    except
      Close;
      Exit;
    end;
    // не закрывать dataset, если пользователь найден
  end;
end;

function TDM1.GetCurrentUserId:integer;
begin
  Result := -1;
  // DataSet must be opened!!
  if not CurrentUser.Active then Exit; //TODO: debug exit code
  if CurrentUser.IsEmpty then Exit;
  CurrentUser.First;
  Result := CurrentUser.FieldByName('id').AsInteger;
end;

function TDM1.GetCurrentUserRole:integer;
begin
  Result := -1;
  // DataSet must be opened!!
  if not CurrentUser.Active then Exit; //TODO: debug exit code
  if CurrentUser.IsEmpty then Exit;
  if CurrentUser.FieldByName('superuser').AsString='*' then Result := USER_ROLE_ADMIN
  else
    if CurrentUser.FieldByName('superuser').AsString='C' then Result := USER_ROLE_CREATOR
    else Result := USER_ROLE_DEFAULT;
end;

function TDM1.GetCurrentUserName:string;
begin
  Result := '';
  // DataSet must be opened!!
  if not CurrentUser.Active then Exit; //TODO: debug exit code
  if CurrentUser.IsEmpty then Exit;
  CurrentUser.First;      // должна быть только одна запись с таким набором login/pass
  Result := CurrentUser.FieldByName('username').AsString;
end;

function TDM1.AddUser(login, pass, username: string; admin: string=''):integer;
begin
  Result := -1;
  if IsEmptyStr(login, [' ',#9,#10,#13]) then Exit;   //TODO: debug log -> login is empty
  //if IsEmptyStr(pass, [' ',#9,#10,#13]) then Exit;   //TODO: pass may be empty ???   debug log -> pass is empty
  with SQLQuery1 do
  begin
    Close;
    SQL.Clear;
    SQL.Text := 'INSERT INTO users (username, login, password, superuser) VALUES (:uname,:ulogin,:upass,:super);';
    SQLQuery1.ParamByName('uname').AsString:=username;
    SQLQuery1.ParamByName('ulogin').AsString:=login;
    SQLQuery1.ParamByName('upass').AsString:=HashPass(pass);
    SQLQuery1.ParamByName('super').AsString:=admin;
    try
      ExecSQL;
      if SQLTransaction.Active then SQLTransaction.CommitRetaining;
      Result := GetLastRowId;
      if Result>0 then
        if not CurrentUser.Locate('id',Result,[]) then CurrentUser.First;  // if not located new record, go to first
    finally
      Close;
    end;
  end;
end;


function TDM1.UpdUser(uid: integer; login, pass, username: string; admin: string=''):boolean;
begin
  Result := False;
  if uid<=0 then Exit;
  if IsEmptyStr(login, [' ',#9,#10,#13]) then Exit;   //TODO: debug log -> login is empty
  //if IsEmptyStr(pass, [' ',#9,#10,#13]) then Exit;   //TODO: pass may be empty ???   debug log -> pass is empty
  with SQLQuery1 do
  try
    Close;
    SQL.Clear;
    SQL.Text := 'UPDATE users SET username=:uname, login=:ulogin, password=:upass, superuser=:super WHERE id=:uid;';
    SQLQuery1.ParamByName('id').AsInteger:=uid;
    SQLQuery1.ParamByName('uname').AsString:=username;
    SQLQuery1.ParamByName('ulogin').AsString:=login;
    SQLQuery1.ParamByName('upass').AsString:=HashPass(pass);
    SQLQuery1.ParamByName('super').AsString:=admin;
    try
      ExecSQL;
      if SQLTransaction.Active then SQLTransaction.CommitRetaining;
      Result := True;
    except
      if SQLTransaction.Active then SQLTransaction.RollbackRetaining;
      Result := False;
      //TODO: debug log
    end;
  finally
    Close;
  end;
end;

function TDM1.DelUser(user_id:integer=-1):boolean;
begin
  //TODO: проверки о наличии связных записей провести перед вызовом функции!!!
  Result := False;
  if user_id <=0 then Exit;   //TODO: debug log -> no user to delete
  // Удалять может только админ
  if GetCurrentUserRole <> USER_ROLE_ADMIN then Exit; //TODO: debug log -> only admin can delete CurrentUser
  // Себя удалять нельзя!!!
  if user_id = GetCurrentUserId then Exit ; //TODO: debug log -> user can't delete yourself
  //
  //удалять единственного админа НЕЛЬЗЯ !! Для этого:
  // 1. Проверить, что удаляемый пользователь - админ
  // 2. посчитать всех админов. Если один, то выход
  if UserIsAdmin(user_id) and  (AdminsCount=1) then Exit; //raise Exception.Create('Невозможно удалить единственного администратора!');
  //--
  with SQLQuery1 do
  try
    Close;
    SQL.Clear;
    SQL.Text := 'DELETE FROM users WHERE id=:uid;';
    SQLQuery1.ParamByName('uid').AsInteger:=user_id;
    try
      ExecSQL;
      if SQLTransaction.Active then SQLTransaction.CommitRetaining;
      Result := True;          //GetLastRowId --??;
      //TODO: если ОЧЕНЬ будет надо, то посчитать к-во записей до и после, разница покажет, сколько удалили
      except
        if SQLTransaction.Active then SQLTransaction.RollbackRetaining;
        Result := False;
      end;
  finally
    Close;
  end;
end;


function TDM1.UserIsAdmin(user_id:integer=-1):boolean;
begin
  Result := False;
  if user_id <=0 then Exit;   //TODO: debug log -> no user to delete
  with SQLQuery1 do
  try
    Close;
    SQL.Clear;
    SQL.Text := 'SELECT * FROM users WHERE id=:uid;';
    SQLQuery1.ParamByName('uid').AsInteger:=user_id;
    try
      Open;
      if IsEmpty then raise Exception.Create('Ошибка: такой пользователь не найден!');   //TODO: debug log
      if  FieldByName('superuser').AsString='*' then Result := True;
    except
      Result := False;
      Exit;
      //TODO: debug log write error
    end;
  finally
    Close;
  end;
end;


function TDM1.AdminsCount:integer;
begin
  Result := 0;
  with SQLQuery1 do
  try
    Close;
    SQL.Clear;
    SQL.Text := 'SELECT COUNT(*) as cnt FROM users WHERE superuser=''*'';';
    try
      Open;
      if IsEmpty then raise Exception.Create('Ошибка: администраторы не найдены???');   //TODO: debug log
      Result := FieldByName('cnt').AsInteger
    except
      Result := 0;
      Exit;
      //TODO: debug log write error
    end;
  finally
    Close;
  end;
end;


//***************
//* Projects
//***************

procedure TDM1.RefreshProjects(role: integer);
begin
  Blocks.Close;
  Templates.Close;
  with Projects do
  try
    Close;
    case role of
      USER_ROLE_DEFAULT:
        begin
          DataSource := nil;
          SQL.Text := 'SELECT * FROM projects;';
        end;
      USER_ROLE_CREATOR:
        begin
          DataSource := CU_DS;
          SQL.Text := 'SELECT * FROM projects WHERE user_id=:id;';
        end;
      else Exit; //don't open DataSet
    end;
    Open;
    Templates.Open;
    Blocks.Open;
  except
    Close;
  end;
end;

function TDM1.AddProject(Info: string='') : integer;
begin
  Result := -1;
  if DM1.GetCurrentUserId<=0 then Exit;
  //TODO:  SQLite3 version only (twin operation: insert + get last row id) !!!!
  If IsEmptyStr(Info,[' ']) then Info := 'Project ('+DateToStr(now)+')';
  with SQLQuery1 do
  begin
    Close;
    SQL.Clear;
    SQL.Text := 'INSERT INTO projects (prjname, prjcreated, prjmodified,prjinfo, user_id) VALUES (:prj_name,CURRENT_DATE,CURRENT_DATE,:info, :userid);';
    SQLQuery1.ParamByName('prj_name').AsString:=HashPass(Info);
    SQLQuery1.ParamByName('info').AsString:=Info;
    SQLQuery1.ParamByName('userid').AsInteger:=DM1.GetCurrentUserId;
    try
      try
        if not SQLTransaction.Active then SQLTransaction.StartTransaction;
        ExecSQL;
        if SQLTransaction.Active then SQLTransaction.CommitRetaining;
        Result := GetLastRowId;
        if Result>0 then
          if not Projects.Locate('id',Result,[]) then Projects.First;  // if not located new record, go to first
      except
        if SQLTransaction.Active then SQLTransaction.RollbackRetaining;
      end;
    finally
      Close;
    end;
  end;
  //TODO:  if PostgreSQL need use 'INSERT ... RETURNING id'  in one query!!!
end;


function TDM1.GetCurrentProjectId:integer;
begin
  //TODO: объединить в одну функцию со вторым параметром - TDataSet (CurrentUser, projects, templates)
  Result := -1;
  // DataSet must be opened!!
  if not Projects.Active then Exit; //TODO: debug exit code
  if Projects.IsEmpty then Exit;
  Result := Projects.FieldByName('id').AsInteger;
end;

function TDM1.GetCurrentProjectInfo:string;
begin
  Result := '';
  // DataSet must be opened!!
  if not Projects.Active then Exit; //TODO: debug exit code
  if Projects.IsEmpty then Exit;
  Result := Projects.FieldByName('prjinfo').AsString;
end;


function TDM1.GetProject(prid : integer) : boolean;
begin
  Result := False;
{
if prid <= 0 then Exit;
  with SQLQuery1 do
  try
    Close;
    //TODO: SQLite SQL script !!
    SQL.Text:='SELECT p.id,p.prjdate,p.prjinfo FROM projects p WHERE p.id=:prid;';
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
}
end;

{ deprecated !!!!!
function TDM1.GetProjectFields : boolean;
begin

  try
    MainForm1.CurrentProject.SetPrj(
      SQLQuery1.FieldByName('id').AsInteger,
      SQLQuery1.FieldByName('prjcreated').AsDateTime,
      SQLQuery1.FieldByName('prjmodified').AsDateTime,
      SQLQuery1.FieldByName('prjinfo').AsString
    );
    Result := True;
  except
    Result := False;
  end;
end;
}

function TDM1.DelProject : boolean;
var
  pid : integer;
begin
  Result := False;
  if not Projects.Active or Projects.IsEmpty then Exit;
  pid := DM1.GetCurrentProjectId;
  if pid<=0 then Exit;
  with SQLQuery1 do
  begin
    Close;
    SQL.Clear;
    SQL.Text := 'DELETE FROM projects where id=:pid;';
    SQLQuery1.ParamByName('pid').AsInteger:=pid;
    try
      try
        if not SQLTransaction.Active then SQLTransaction.StartTransaction;
        ExecSQL;
        if SQLTransaction.Active then SQLTransaction.CommitRetaining;
        Result := True;
      except
        if SQLTransaction.Active then SQLTransaction.RollbackRetaining;
      end;
    finally
      Close;
    end;
  end;
end;

//**************

{ Blocks }

procedure TDM1.BlocksOpen;
begin
{  if MainForm1.CurrentUser.id <= 0 then Exit;
  with Templates do
  begin
    Close;
    SQL.Text:='SELECT * FROM blocks ORDER BY blockorder';
  end;
}
end;

function TDM1.GetCurrentBlockId : integer;
begin
  Result := -1;
  if not Blocks.Active then Exit;
  if Blocks.IsEmpty then Exit;
  Result := Blocks.FieldByName('id').AsInteger;
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
  with Templates do
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


function TDM1.AddBlk2DB(temp_id: integer; blk: string; blord:integer=0):integer;
begin
  Result := -1;
  temp_id:= GetCurrentTemplateId;
  if (temp_id<=0) or IsEmptyStr(blk,[' ',#9,#10,#13]) then Exit;
  with SQLQuery1 do
  try
    Close;
    SQL.Text := 'INSERT INTO blocks (blockorder,blockname,tmp_id) '+
             ' VALUES (:bord,:bname,:temp_id);';
    try
      ParamByName('bord').AsInteger := blord;
      ParamByName('bname').AsString := blk;
      ParamByName('temp_id').AsInteger := temp_id;
      ExecSQL;
      if Transaction.Active then TSQLTransaction(Transaction).CommitRetaining;
      Result := GetLastRowId;
    except
      // showmessage('error... '); -?
      if Transaction.Active then TSQLTransaction(Transaction).Rollback;
      Exit;
    end;
  finally
    Close;
  end;
end;

{function TDM1.AddBlock2DB(blk : TBlock):integer;
var
  temp_id : integer;
begin
  Result := -1;
  temp_id:= GetCurrentTemplateId;
  if (temp_id<=0) or not Assigned(blk) then Exit;
  with SQLQuery1 do
  try
    Close;
    SQL.Text := 'INSERT INTO blocks (blockorder,blockname,blockinfo,tmp_id) '+
             ' VALUES (:bord,:bname,:binfo,:temp_id);';
    try
      ParamByName('bord').AsInteger := blk.order;
      ParamByName('bname').AsString := blk.name;
      ParamByName('binfo').AsString := blk.info;
      ParamByName('temp_id').AsInteger := temp_id;
      ExecSQL;
      if Transaction.Active then TSQLTransaction(Transaction).CommitRetaining;
      Result := GetLastRowId;
    except
      // showmessage('error... '); -?
      if Transaction.Active then TSQLTransaction(Transaction).Rollback;
      Exit;
    end;
  finally
    Close;
  end;
end;
}

function TDM1.InsertBlocks2DB(blks : TObjectList {list of TBlock}; temp_id : integer = -1):boolean; // temp_id default =-1 --> to exclude bugs
var
  i: integer;
begin
  Result := False;
  if (temp_id<=0) or not Assigned(blks) then Exit;
  with SQLQuery1 do
  try
    Close;
    SQL.Text := 'INSERT INTO blocks (blockorder,blockname,blockinfo,tmp_id) '+
             ' VALUES (:bord,:bname,:binfo,:temp_id);';
    Prepare;
    for i:=0 to blks.Count-1 do
    try
      ParamByName('bord').AsInteger := TBlock(blks[i]).order;
      ParamByName('bname').AsString := TBlock(blks[i]).name;
      ParamByName('binfo').AsString := TBlock(blks[i]).info;
      ParamByName('temp_id').AsInteger := temp_id;
      ExecSQL;
      if Transaction.Active then TSQLTransaction(Transaction).CommitRetaining;
    except
      // showmessage('error... '); -?
      if Transaction.Active then TSQLTransaction(Transaction).Rollback;
      Exit;
    end;
    Result := True;
  finally
    Close;
  end;
end;

{
function TDM1.UpdBlockInDB(blk : TBlock; temp_id : integer = -1):boolean;
begin
  Result := False;
  if (temp_id<=0) or not Assigned(blk) then Exit;
  with SQLQuery1 do
  try
    Close;
    SQL.Text := 'UPDATE blocks SET blockorder=:bord, blockname=:bname, blockinfo=:binfo WHERE id=:bid and tmp_id=:temp_id;';
    ParamByName('bid').AsInteger := TBlock(blk).id;
    ParamByName('bord').AsInteger := TBlock(blk).order;
    ParamByName('bname').AsString := TBlock(blk).name;
    ParamByName('binfo').AsString := TBlock(blk).info;
    ParamByName('temp_id').AsInteger := temp_id;
    try
      ExecSQL;
      if Transaction.Active then TSQLTransaction(Transaction).CommitRetaining;
    except
      // showmessage('error... '); -?
      if Transaction.Active then TSQLTransaction(Transaction).Rollback;
      Exit;
    end;
    Result := True;
  finally
    Close;
  end;
end;
 }

function TDM1.SaveBlocks2DB(blks : TObjectList {list of TBlock}; temp_id : integer = -1):boolean;
var
  i: integer;
begin
  Result := False;
  if (temp_id<=0) or not Assigned(blks) then Exit;
  with SQLQuery1 do
  try
    Close;
    SQL.Text := 'UPDATE blocks SET blockorder=:bord, blockname=:bname, blockinfo=:binfo WHERE id=:bid and tmp_id=:temp_id;';
    Prepare;
    for i:=0 to blks.Count-1 do
    try
      ParamByName('bid').AsInteger := TBlock(blks[i]).id;
      ParamByName('bord').AsInteger := TBlock(blks[i]).order;
      ParamByName('bname').AsString := TBlock(blks[i]).name;
      ParamByName('binfo').AsString := TBlock(blks[i]).info;
      ParamByName('temp_id').AsInteger := temp_id;
      ExecSQL;
      if Transaction.Active then TSQLTransaction(Transaction).CommitRetaining;
    except
      if Transaction.Active then TSQLTransaction(Transaction).Rollback;
      // showmessage('error... '); -?
      Exit;
    end;
    Result := True;
  finally
    Close;
  end;
end;

function TDM1.SaveBlockInfo(bid:integer=-1; binfo:string=''):boolean;
begin
  Result := False;
  if (bid<=0) then Exit;
  with SQLQuery1 do
  try
    Close;
    SQL.Text := 'UPDATE blocks SET blockinfo=:binfo WHERE id=:bid';
    ParamByName('bid').AsInteger := bid;
    ParamByName('binfo').AsString := binfo;
    try
      ExecSQL;
      if Transaction.Active then TSQLTransaction(Transaction).CommitRetaining;
      Blocks.Refresh;
      Blocks.Locate('id',bid,[]);
      Result := True;
    except
      // showmessage('error... '); -?
      if Transaction.Active then TSQLTransaction(Transaction).Rollback;
    end;
  finally
    Close;
  end;
end;

//**************

{ Templates }

function TDM1.GetCurrentTemplateId:integer;
begin
  Result := -1;
  // DataSet must be opened!!
  if not Templates.Active then Exit; //TODO: debug exit code
  if Templates.IsEmpty then Exit;
  Result := Templates.FieldByName('id').AsInteger;
end;

function TDM1.GetCurrentTempName:string;
begin
  Result := '';
  // DataSet must be opened!!
  if not Templates.Active then Exit; //TODO: debug exit code
  if Templates.IsEmpty then Exit;
  Result := Templates.FieldByName('tmpname').AsString;
end;


function TDM1.AddTemplate(prj_id: integer; TempName,FName: string):integer;
begin
  Result := -1;
  if (prj_id<=0) or not FileExists(FName) then Exit;
  with SQLQuery1 do
  try
    Close;
    SQL.Text:='INSERT INTO templates (prj_id,tmpname,tmp) VALUES(:prjid,:tempname,:tmpfile);';
    ParamByName('prjid').AsInteger := prj_id;
    ParamByName('tempname').AsString := TempName;
    try
      ParamByName('tmpfile').LoadFromFile(FName,ftBlob);
      if not SQLTransaction.Active then SQLTransaction.StartTransaction;
      ExecSQL;
      if SQLTransaction.Active then SQLTransaction.CommitRetaining;
      Result := GetLastRowId;
    except
      if SQLTransaction.Active then SQLTransaction.RollbackRetaining;
    end;
  finally
    Close;
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

function TDM1.DelTemplate(tmp_id: integer=-1):boolean;
begin
  Result := False;
  if tmp_id<=0 then Exit;
  //TODO: ...
end;


//**************

{ Content }

procedure TDM1.OpenContent(uid, bid : integer);
begin
  if (uid<=0) or (bid<=0) then Exit;
  with Content do
  begin
    Close;
    Params.Clear;
    SQL.Text:='SELECT id,conttext FROM content WHERE user_id=:uid AND block_id=:bid;';
    ParamByName('uid').AsInteger:=uid;
    ParamByName('bid').AsInteger:=bid;
    try
      Open;
    except
      //TODO: debug log write error
    end;
  end;
end;

procedure TDM1.CloseContent;
begin
  try
    Content.Close;
  except
    //TODO: debug log write error
  end;
end;

function TDM1.GetContentId(uid, bid : integer):integer;
begin
  Result := -1;
  with SQLQuery1 do
  try
    Close;
    Params.Clear;
    SQL.Text:='SELECT id FROM content WHERE user_id=:uid and block_id=:bid;';
    ParamByName('uid').AsInteger := uid;
    ParamByName('bid').AsInteger := bid;
    try
      Open;
      if RecordCount<1 then Exit;
      First;
      Result := FieldByName('id').AsInteger;
    except
      //TODO: debug log ...
    end;
  finally
    Close;
  end;
end;

function TDM1.GetContentText(cid: integer):string;
begin
  Result := '';
  with SQLQuery1 do
  try
    Close;
    Params.Clear;
    SQL.Text:='SELECT conttext FROM content WHERE id=:cid;';
    ParamByName('cid').AsInteger := cid;
    try
      Open;
      if RecordCount<1 then Exit;
      First;
      Result := FieldByName('conttext').AsString;
    except
      //TODO: debug log ...
    end;
  finally
    Close;
  end;
end;

function TDM1.AddContent2DB(uid, bid : integer; cont:string=''; UpdateIfExist:boolean=False):integer;
begin
  //TODO:
  //1. seek in content record with user_id=:uid and block_id=:bid
  // if found - SQLQuery1.SQL.Text = 'UPDATE content ...
  // else SQLQuery1.SQL.Text = 'INSERT INTO content...
  Result := -1;
  if (uid<=0) or (bid<=0) then Exit;
  Result := GetContentId(uid,bid);
  if Result>0 then
  begin
    if UpdateIfExist then
      if UpdContent(Result,cont) then Exit; // OK
    Result := -1; // can't update - error
    Exit;
  end;
  with SQLQuery1 do
  try
    Close;
    Params.Clear;
    SQL.Text:='INSERT INTO content (user_id,block_id, conttext) VALUES (:uid,:bid,:cont);';
    ParamByName('uid').AsInteger := uid;
    ParamByName('bid').AsInteger := bid;
    ParamByName('cont').AsString := cont;
    try
      if not SQLTransaction.Active then SQLTransaction.StartTransaction;
      ExecSQL;
      if SQLTransaction.Active then SQLTransaction.CommitRetaining;
      Result := GetLastRowId;
    except
      if SQLTransaction.Active then SQLTransaction.RollbackRetaining;
      Result := -1;
    end;
  finally
    Close;
  end;
end;

function TDM1.UpdContent(cid: integer; cont:string=''):boolean;
begin
  Result := False;
  if cid<=0 then Exit;
  with SQLQuery1 do
  try
    Close;
    SQL.Text:='UPDATE content SET conttext=:cont WHERE id=:cid;';
    ParamByName('cid').AsInteger := cid;
    ParamByName('cont').AsString := cont;
    try
      if not SQLTransaction.Active then SQLTransaction.StartTransaction;
      ExecSQL;
      if SQLTransaction.Active then SQLTransaction.CommitRetaining;
      Result := True;
    except
      if SQLTransaction.Active then SQLTransaction.RollbackRetaining;
      Result := False;
    end;
  finally
    Close;
  end;
end;

//********

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

