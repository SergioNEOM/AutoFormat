unit mainform;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqlite3conn, sqldb, Forms, Controls, Graphics, Dialogs,
  StdCtrls, ActnList, Menus, DBGrids, DBCtrls, CommonUnit, DM;

type

  { TMainForm1 }

  TMainForm1 = class(TForm)
    Button1: TButton;
    DBGrid1: TDBGrid;
    DBGrid2: TDBGrid;
    DBGrid3: TDBGrid;
    DelPrjAction: TAction;
    ClosePrjAction: TAction;
    FormatAction: TAction;
    MainMenu1: TMainMenu;
    MenuItem1: TMenuItem;
    MenuItem10: TMenuItem;
    MenuItem2: TMenuItem;
    MenuItem3: TMenuItem;
    MenuItem4: TMenuItem;
    N3: TMenuItem;
    N1: TMenuItem;
    MenuItem5: TMenuItem;
    MenuItem6: TMenuItem;
    MenuItem7: TMenuItem;
    MenuItem8: TMenuItem;
    MenuItem9: TMenuItem;
    N2: TMenuItem;
    OpenPrjAction: TAction;
    NewPrjAction: TAction;
    ExitAppAction: TAction;
    ChangeUserAction: TAction;
    ActionList1: TActionList;
    ActionImages: TImageList;
    procedure Button1Click(Sender: TObject);
    procedure ChangeUserActionExecute(Sender: TObject);
    procedure DBComboBox1Change(Sender: TObject);
    procedure ExitAppActionExecute(Sender: TObject);
    procedure FormatActionExecute(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure NewPrjActionExecute(Sender: TObject);
    procedure OpenPrjActionExecute(Sender: TObject);
  private
    AppStarted : boolean;
    function GetConfigFile : boolean;
    function GetConfigValues : boolean;
  public
    DBFile,
    ConfigFile               : string;
    CurrentUser    : TUserRec;
    CurrentBlock   : TBlock;
    CurrentProject : TPrjRec;
    procedure ShowLogin;
  end;

var
  MainForm1: TMainForm1;

implementation

{$R *.lfm}
uses  StrUtils, LCLType, IniFiles, LoginFrm, ListFrm, GetFileFrm, ProjectFrm, Processing;


procedure TMainForm1.FormCreate(Sender: TObject);
begin
  AppStarted:=True;
  CurrentUser := TUserRec.Create;
  CurrentUser.Clear;
  CurrentBlock := TBlock.Create;
  CurrentBlock.Clear;
  CurrentProject := TPrjRec.Create;
  CurrentProject.Clear;
end;

procedure TMainForm1.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  if DM1.SQLite3Connection1.Connected  then
  begin
    if DM1.SQLTransaction1.Active then
    try
      DM1.SQLTransaction1.Commit;
    except
      DM1.SQLTransaction1.Rollback;
    end;
    DM1.SQLite3Connection1.Connected:=False;
  end;
  CanClose:=True;
end;


procedure TMainForm1.ChangeUserActionExecute(Sender: TObject);
begin
  CurrentUser.Clear;
  self.Caption:= AppHeader;
  ShowLogin;
end;

procedure TMainForm1.DBComboBox1Change(Sender: TObject);
begin

end;

procedure TMainForm1.Button1Click(Sender: TObject);
begin
  DM1.Projects.Open;
  DM1.Templates.Open;
  DM1.Blocks.Open;

end;


procedure TMainForm1.ExitAppActionExecute(Sender: TObject);
begin
  Close;
end;

procedure TMainForm1.FormatActionExecute(Sender: TObject);
begin
  TaskForm.Format(1,ExpandFileName('Lorem ipsum.docx'),0{Word});
end;

procedure TMainForm1.FormShow(Sender: TObject);
begin
  if AppStarted then
  begin
    AppStarted:=False; // no more pass
    //---
    if not GetConfigFile then
      with TGetFileForm1.Create(self) do
      try
        if ShowModal<>mrOK then
        begin
          Application.MessageBox('Не найден файл конфигурации! '+#13#10+'Приложение будет закрыто.','Ошибка',MB_ICONERROR+MB_OK);
          Halt(999);
        end;
        ConfigFile:=FileNameEdit1.FileName;
      finally
        Free;
      end;
    //---
    if not GetConfigValues then
    begin
      Application.MessageBox('Недостаточно информации в файле конфигурации! '+#13#10+'Приложение будет закрыто.','Ошибка',MB_ICONERROR+MB_OK);
      Halt(99);
    end;
    //---
    DM1.DBConnect;
    //---
    ShowLogin;
  end;
end;


function TMainForm1.GetConfigFile : boolean;
begin
  Result := False;
  ConfigFile :=  Application.GetOptionValue('c','config');
  if IsEmptyStr(ConfigFile,[' ']) then
    ConfigFile := ExtractFilePath(Application.ExeName)+ExtractFileName(Application.ExeName)+'.ini';
  //
  ConfigFile:= ExpandFileName(ConfigFile);
  if FileExists(ConfigFile) then Result := True;
end;

function TMainForm1.GetConfigValues : boolean;
var
  cofi : TIniFile;
begin
  Result := False;
  //---
  DBFile :=  Application.GetOptionValue('d','dbfile');
  if IsEmptyStr(DBFile,[' ']) or not FileExists(ExpandFileName(DBFile)) then
  begin
    // не передан как параметр или указан несуществующий файл БД, значит берем из конфиг-файла
    cofi := TIniFile.Create(ConfigFile);
    DBFile := ExpandFileName(cofi.ReadString('db','DBFile',''));
    if not FileExists(DBFile) then Exit;
  end;
  //...
  Result := True;
end;

procedure TMainForm1.NewPrjActionExecute(Sender: TObject);
var
  n : integer;
  v : string ;
begin
  v := '';
  if InputQuery('Новый проект','Укажите описание проекта'+#13#10+'...или откажитесь от создания (кнопка "Cancel")',v)  then
  begin
    n := DM1.AddProject(v);
    if n<=0 then
    begin
      Application.MessageBox('Не удалось добавить новый проект','ERROR',MB_ICONASTERISK+MB_OK);
      Exit;
    end;
  end;
  OpenPrjAction.Execute;
end;


procedure TMainForm1.OpenPrjActionExecute(Sender: TObject);
begin
  if CurrentUser.id <=0 then Exit;
  // prepare SQLQuery
  with DM1.SQLQuery1 do
  begin
    Close;
    //SQL.Text:='SELECT p.*,length(t.tmp) as lentmp FROM projects p, templates t WHERE t.prj_id=p.id and p.user_id=:u';
    SQL.Text:='SELECT p.* FROM projects p WHERE p.user_id=:u;';
    ParamByName('u').Value:=CurrentUser.id;
    try
      Open;
    except
      Application.MessageBox('projects list error','ERROR',MB_ICONERROR+MB_OK);
      Exit;
    end;
  end;
  //TODO: вынести в функцию ???  --
  with TListForm1.Create(self,DM1.DataSource1,'Проекты',CurrentProject.id) do
  try
     if ShowModal = mrOk then
     begin
       // project parameters...
       if not DM1.GetProjectFields then
       begin
         MainForm1.CurrentProject.Clear;
         Application.MessageBox('error save projects data','ERROR',MB_ICONERROR+MB_OK);
         Exit;
       end;
     end;
  finally
    Free;
  end;
  //---
  if  CurrentProject.id <=0 then Exit;
//  with TProjectForm.Create(self,MainForm1.CurrentProject.id) do
  with TProjectForm.Create(self) do
  try
    if ShowModal=mrOk then
    begin
      //TODO: записать в БД
      showmessage('project saved -?');
    end;
    // else ...  if modified ... are you sure?
  finally
    Free;
  end;

end;


procedure TMainForm1.ShowLogin;
begin
  with TLoginForm.Create(self) do
  try
    if ShowModal <> mrOK then Close; // exiting from app
    // CurrentUser was set in LoginForm
  finally
    Free;
  end;
  self.Caption:= AppHeader + ' : ' + CurrentUser.name;
  if CurrentUser.super then  self.Caption:= self.Caption + ' (***)';
end;




end.

