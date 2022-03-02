unit mainform;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqlite3conn, sqldb, Forms, Controls, Graphics, Dialogs,
  StdCtrls, ActnList, Menus, DBGrids, DBCtrls, ExtCtrls, Buttons, ComCtrls,
  CommonUnit, DM;

type

  { TMainForm1 }

  TMainForm1 = class(TForm)
    DelUserAction: TAction;
    AddUserAction: TAction;
    EditTmpAction: TAction;
    DelTmpAction: TAction;
    PrjDBGrid: TDBGrid;
    ProgressBar1: TProgressBar;
    TempDBGrid: TDBGrid;
    DelPrjAction: TAction;
    FormatAction: TAction;
    MainMenu1: TMainMenu;
    MenuItem1: TMenuItem;
    MenuItem10: TMenuItem;
    MenuItem11: TMenuItem;
    MenuItem12: TMenuItem;
    OpenDialog1: TOpenDialog;
    Separator4: TMenuItem;
    Separator3: TMenuItem;
    Separator2: TMenuItem;
    Separator1: TMenuItem;
    MenuItem2: TMenuItem;
    MenuItem3: TMenuItem;
    MenuItem4: TMenuItem;
    N1: TMenuItem;
    MenuItem5: TMenuItem;
    MenuItem6: TMenuItem;
    MenuItem7: TMenuItem;
    MenuItem8: TMenuItem;
    MenuItem9: TMenuItem;
    N2: TMenuItem;
    NewTmpAction: TAction;
    NewPrjAction: TAction;
    ExitAppAction: TAction;
    ChangeUserAction: TAction;
    ActionList1: TActionList;
    ActionImages: TImageList;
    Panel1: TPanel;
    Panel2: TPanel;
    Panel3: TPanel;
    SpeedButton1: TSpeedButton;
    SpeedButton2: TSpeedButton;
    SpeedButton3: TSpeedButton;
    SpeedButton4: TSpeedButton;
    SpeedButton5: TSpeedButton;
    Splitter1: TSplitter;
    StatusBar1: TStatusBar;
    procedure ChangeUserActionExecute(Sender: TObject);
    procedure DelPrjActionExecute(Sender: TObject);
    procedure DelTmpActionExecute(Sender: TObject);
    procedure EditTmpActionExecute(Sender: TObject);
    procedure ExitAppActionExecute(Sender: TObject);
    procedure FormatActionExecute(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure NewPrjActionExecute(Sender: TObject);
    procedure NewTmpActionExecute(Sender: TObject);
  private
    AppStarted : boolean;
    function GetConfigFile : boolean;
    function GetConfigValues : boolean;
    procedure SetAccessibility;
  public
    DBFile,
    ConfigFile               : string;
    CurrentBlock   : TBlock;
    procedure ShowLogin;
  end;

var
  MainForm1: TMainForm1;

implementation

{$R *.lfm}
uses  StrUtils, LCLType, IniFiles, LoginFrm, ListFrm, GetFileFrm, Blockfrm;


procedure TMainForm1.FormCreate(Sender: TObject);
begin
  AppStarted:=True;
//  CurrentUser := TUserRec.Create;
//  CurrentUser.Clear;
  CurrentBlock := TBlock.Create;
  CurrentBlock.Clear;
  //CurrentProject := TPrjRec.Create;
  //CurrentProject.Clear;
  StatusBar1.Panels[0].Width := StatusBar1.Canvas.TextWidth(StringOfChar('W',30));
  //
  ProgressBar1.Parent := StatusBar1;
  ProgressBar1.Top:=4;
  ProgressBar1.Left := StatusBar1.Panels[0].Width + 4;
  ProgressBar1.Height := StatusBar1.ClientHeight - ProgressBar1.Top - 2;
  ProgressBar1.Width := StatusBar1.ClientWidth - ProgressBar1.Left -  20 ;
  ProgressBar1.Min := 0;
  ProgressBar1.Position :=0;
  ProgressBar1.Step := 1;
  ProgressBar1.Smooth := False;//True;
end;

procedure TMainForm1.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  if DM1.SQLite3Connection1.Connected  then
  begin
    if DM1.SQLTransactionMain.Active then
    try
      DM1.SQLTransactionMain.Commit;
      if DM1.Blocks.Active then DM1.Blocks.Close;
      if DM1.Templates.Active then DM1.Templates.Close;
      if DM1.Projects.Active then DM1.Projects.Close;
    except
      DM1.SQLTransactionMain.Rollback;
    end;
    DM1.SQLite3Connection1.Connected:=False;
  end;
  CanClose:=True;
end;

procedure TMainForm1.SetAccessibility;
var
  i, ur :integer;
begin
  for i:= 0 to ActionList1.ActionCount-1 do
  begin
    TAction(ActionList1.Actions[i]).Enabled:=False;
    {
    AddUserAction.Enabled:=False;
    DelUserAction.Enabled:=False;
    NewPrjAction.Enabled := False;
    DelPrjAction.Enabled:=False;
    NewTmpAction.Enabled:=False;
    EditTmpAction.Enabled:=False;
    DelTmpAction.Enabled:=False;
    FormatAction.Enabled:=False;
    }
  end;
  //
  ChangeUserAction.Enabled := True;
  ExitAppAction.Enabled := True;
  //--
  if DM1.GetCurrentUserId<=0 then Exit;
  ur := DM1.GetCurrentUserRole;
  case ur of
    USER_ROLE_ADMIN:
      begin
        AddUserAction.Enabled:=True;
        DelUserAction.Enabled:=True;
      end;
    USER_ROLE_CREATOR:
      begin
        NewPrjAction.Enabled := True;
        DelPrjAction.Enabled := True;
        NewTmpAction.Enabled := True;
        EditTmpAction.Enabled := True;
        DelTmpAction.Enabled := True;
        FormatAction.Enabled := True;
      end;
    else
      begin
        FormatAction.Enabled:=True;
      end;
  end;
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
    //---
    SetAccessibility;
  end;
end;

procedure TMainForm1.ChangeUserActionExecute(Sender: TObject);
begin
  //CurrentUser.Clear;
  self.Caption:= AppHeader;
  ShowLogin;
end;

procedure TMainForm1.DelPrjActionExecute(Sender: TObject);
begin
  if MessageDlg('Подтвердите удаление','ВНИМАНИЕ!!!'+#13#10+'Проект, все шаблоны и все данные для заполнения будут удалены безвозвратно!'+#13#10+'Вы уверены?',mtConfirmation,mbYesNo,'')=mrYes then
    if DM1.DelProject then PrjDBGrid.DataSource.DataSet.Refresh //TODO: debug log : project was deleted
    else showmessage('Ошибка удаления проекта');
end;

procedure TMainForm1.DelTmpActionExecute(Sender: TObject);
begin
  if MessageDlg('Подтвердите удаление','ВНИМАНИЕ!!!'+#13#10+'Шаблон '+DM1.GetCurrentTempName+#13#10+
     'и все данные для его заполнения будут удалены безвозвратно!'+#13#10+'Вы уверены?',mtConfirmation,mbYesNo,'')=mrYes then
    if DM1.DelTemplate(DM1.GetCurrentTemplateId) then TempDBGrid.DataSource.DataSet.Refresh //TODO: debug log : template was deleted
    else showmessage('Ошибка удаления шаблона');
end;

procedure TMainForm1.EditTmpActionExecute(Sender: TObject);
begin
  with TBlocksForm.Create(self) do
  try
    ShowModal;
  finally
    Free;
  end;
end;


procedure TMainForm1.ExitAppActionExecute(Sender: TObject);
begin
  Close;
end;

procedure TMainForm1.FormatActionExecute(Sender: TObject);
begin
  //TODO: ???
  //TaskForm.Format(1,ExpandFileName('Lorem ipsum.docx'),0{Word});
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
    PrjDBGrid.DataSource.DataSet.Refresh;
  end;
end;

//TODO: set OpenDialog1.InitialDir=Applicaion.workPath ???
procedure TMainForm1.NewTmpActionExecute(Sender: TObject);
var
  v : string;
  r : integer;
  sc : TCursor;
begin
  v := '';
  if not InputQuery('Новый шаблон:','Укажите наименование шаблона'+#13#10+'...или откажитесь от создания (кнопка "Cancel")',v)  then Exit;
  // 0. Запрос имени шаблона
  // 1. Выбрать файл (OpenFile Dialog)
  // 2. Определить тип .... ?   Default - Word
  // 3. Сканировать документ
  // 4. Если блоки найдены, создать запись нового шаблона в БД, получить её id, сделать её текущей в DataSet
  // 5. Найденные блоки записать в БД с привязкой к id нового шаблона
  // 6. Сообщить пользователю количество найденных блоков.
  if not OpenDialog1.Execute then Exit; //TODO: debug info: no file selected for new template
  //...
  { 3.
  with TTaskForm.Create(self, DM1.GetCurrentProjectId, OpenDialog1.FileName, TASK_TEST {TASK_WORD_SCAN}) do
  try
    if ShowModal = mrOk then showmessage('Ok')
    else ShowMessage('cancelled');
  finally
    Free;
  end;
  }
  r := DM1.AddTemplate(DM1.GetCurrentProjectId, v, OpenDialog1.FileName);
  if r<=0 then
  begin
    showmessage('error adding template');
    Exit; //TODO: debug log : error adding template
  end;
  TempDBGrid.DataSource.DataSet.Refresh;
  if TempDBGrid.DataSource.DataSet.Active then TempDBGrid.DataSource.DataSet.Locate('id',r,[]);
  //
  sc := GetCursor; // save prev cursor
  try
    self.Cursor := crHourGlass;
    r := WordScan2DB(r,OpenDialog1.FileName,ProgressBar1);
  finally
    self.Cursor := sc;
  end;
  showmessage('Сканирование документа завершено'+#13#10+'Добавлено: '+IntToStr(r)+' блоков');
  //
  ProgressBar1.Position:=0;
  if DM1.Blocks.Active then DM1.Blocks.Refresh;    //TODO: вынести в DM

  {
  if DM1.GetCurrentUserId <=0 then Exit;
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
 }
end;


procedure TMainForm1.ShowLogin;
var
  prevUser : Integer;
begin
  prevUser:= DM1.GetCurrentUserId;
  with TLoginForm.Create(self) do
  try
    if ShowModal <> mrOK then
    begin
      if prevUser<=0 then MainForm1.Close; // no prev user? exiting from app!, else - do nothing
      Exit;
    end;
  finally
    Free;
  end;
  //TODO: есть сомнения, правильно ли отрабатывает в случае отказа от выбора
  //self.Caption:= AppHeader + ' : ' + DM1.GetCurrentUserName;
  StatusBar1.Panels[0].Text := DM1.GetCurrentUserName;
  case DM1.GetCurrentUserRole of
    USER_ROLE_ADMIN   : StatusBar1.Panels[0].Text := StatusBar1.Panels[0].Text + '(*)';
    USER_ROLE_CREATOR : StatusBar1.Panels[0].Text := StatusBar1.Panels[0].Text + '(Creator)';
  end;
  self.SetFocus;
  self.BringToFront;
  DM1.Projects.Open;
  DM1.Templates.Open;
  DM1.Blocks.Open;
end;




end.

