unit mainform;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqlite3conn, sqldb, Forms, Controls, Graphics, Dialogs,
  StdCtrls, ActnList, Menus, JSONPropStorage, IniPropStorage, CommonUnit, DM;

type

  { TMainForm1 }

  TMainForm1 = class(TForm)
    Button1: TButton;
    DelPrjAction: TAction;
    ClosePrjAction: TAction;
    FormatAction: TAction;
    ListBox1: TListBox;
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
    function Format(prj: integer; TargetFile: Widestring): boolean;
  end;

var
  MainForm1: TMainForm1;

implementation

{$R *.lfm}
uses      {$IFDEF WINDOWS} ComObj, {$ENDIF}
    StrUtils, LCLType, IniFiles, LoginFrm, ListFrm, GetFileFrm, ProjectFrm;


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

procedure TMainForm1.Button1Click(Sender: TObject);
var
  s : TStrings;
begin
  s := TStrings.Create;
  DM1.FillBlockNames(s,1);
  ListBox1.Items.AddStrings(s);
  s.Free;
end;

procedure TMainForm1.ExitAppActionExecute(Sender: TObject);
begin
  Close;
end;

procedure TMainForm1.FormatActionExecute(Sender: TObject);
begin
  Format(1,ExpandFileName('Lorem ipsum.docx'));
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
    SQL.Text:='SELECT p.*,length(t.tmp) as lentmp FROM projects p, templates t WHERE t.prj_id=p.id and p.user_id=:u';
    ParamByName('u').Value:=CurrentUser.id;
    try
      Open;
    except
      Application.MessageBox('projects list error','ERROR',MB_ICONERROR+MB_OK);
      Exit;
    end;
  end;
  //--
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
  if  MainForm1.CurrentProject.id <=0 then Exit;

//  with TProjectForm.Create(self,MainForm1.CurrentProject.id) do
  with TProjectForm.Create(self) do
  try
    if ShowModal=mrOk then showmessage('project saved');
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


function TMainForm1.Format(prj: integer; TargetFile: WideString): boolean;
{$IFDEF WINDOWS}
const
  prefix = '{<block';
  suffix = '>}';
var
     WA : OleVariant;
     c, cc, i : integer;
     SeekStr, ReplStr : WideString;
begin
  Result := False;
  try
     WA := CreateOLEObject('Word.Application');
  except
     Application.MessageBox(PAnsiChar('Не могу начать работу с MS Word ('+TargetFile+')'),'Ошибка',MB_OK+MB_ICONEXCLAMATION);
     //Abort;
     Exit;
  end;
  try
    WA.Visible := False;
    cc := 3;     // количество проходов по документу:
                 // (1) - тело докум.; (2) - верхний колонтитул; (3)- нижний колонтитул;
    WA.Caption := 'AutoFormat: fill data to Word document';
    WA.Documents.Open(TargetFile);
    WA.ActiveWindow.View.&Type := 3 { wdPageView };
    // если колонтитулы первой страницы отличаются от остальных, то на два прохода больше:
    // (1) - тело докум.; (2) - верхний колонтитул 1 стр.; (3)- нижний колонтитул 1 стр.;
    // (4) - верхний колонтитул со 2-й стр.; (5) - нижний колонтитул со 2-й стр.
    {
     wdSeekCurrentPageFooter    =	10	The current page footer.
     wdSeekCurrentPageHeader    = 9	The current page header.
     wdSeekEndnotes             =	8	Endnotes.
     wdSeekEvenPagesFooter      =	6	The even pages footer.
     wdSeekEvenPagesHeader      =	3	The even pages header.
     wdSeekFirstPageFooter      =	5	The first page footer.
     wdSeekFirstPageHeader      =	2	The first page header.
     wdSeekFootnotes            =	7	Footnotes.
     wdSeekMainDocument         =	0	The main document.
     wdSeekPrimaryFooter        =	4	The primary footer.
     wdSeekPrimaryHeader        =	1	The primary header.
    }
    if WA.ActiveDocument.PageSetup.DifferentFirstPageHeaderFooter then Inc(cc,2);
    //Gauge.Max :=DS.FieldCount * cc;
    for c:=1 to cc do
    begin
      case c of
        1: WA.ActiveWindow.ActivePane.View.SeekView := 0; //wdSeekMainDocument;
        2: WA.ActiveWindow.ActivePane.View.SeekView := 9; //wdSeekCurrentPageHeader;
        3: WA.ActiveWindow.ActivePane.View.SeekView := 10; //wdSeekCurrentPageFooter;
        4: begin
             try   // если в документе колонтитулы не различаются, то возникает ошибка
               WA.ActiveWindow.ActivePane.View.SeekView := 9; //wdSeekCurrentPageHeader;
               WA.ActiveWindow.ActivePane.View.NextHeaderFooter;
             except
               continue;   // нет колонтитулов - и не надо ...
             end;
           end;
        5: begin
             try   // см. выше ( = 4)
               WA.ActiveWindow.ActivePane.View.SeekView := 10; //wdSeekCurrentPageFooter;
               WA.ActiveWindow.ActivePane.View.NextHeaderFooter;
             except
               continue;
             end;
           end;
      end;  //case
      //-
      for i:=1 to 4 do
      begin
        SeekStr := prefix + trim(inttostr(i))+suffix ;
        ReplStr := '!!!@@@'+ trim(inttostr(i));
        showmessage('Seek: '+SeekStr+'  ->  Replace: '+ReplStr);
        WA.Selection.Find.ClearFormatting;
        WA.Selection.Find.Replacement.ClearFormatting;
        // Сделать текст видимым после замены:
        WA.Selection.Find.Replacement.Font.Hidden := False;
        WA.Selection.Find.Text := UTF8Decode(SeekStr) ;
        WA.Selection.Find.Replacement.Text := UTF8Decode(ReplStr);
        WA.Selection.Find.Forward := True;
        WA.Selection.Find.Wrap := 1 { wdFindContinue };
        // если ищем скрытый текст (т.е. по формату):
        WA.Selection.Find.Format := True;
        WA.Selection.Find.MatchCase := False;
        WA.Selection.Find.MatchWholeWord := False;
        WA.Selection.Find.MatchWildCards := False;
        WA.Selection.Find.MatchSoundsLike := False;
        WA.Selection.Find.MatchAllWordForms := False;
        WA.Selection.Find.Execute(Replace := 2 { wdReplaceAll } );
        Application.ProcessMessages;
      end; //for i
    end;   // for c
    WA.ActiveWindow.ActivePane.View.SeekView := 0; //wdSeekMainDocument;
    try
      WA.ActiveDocument.Save;
      Result := True;
      showmessage('Document saved'); //TODO: Application.MessageBox
    except
      raise Exception.Create('Не могу сохранить документ '+TargetFile+#13#10+'Изменения не будут записаны');
    end;
  finally
    WA.ActiveDocument.Close;
    WA.ScreenUpdating := True;
    WA.Quit;
  end;
  {
  procedure TForm1.MakeDocs(FN: String; DS:TDataSet);
var
   WA : OleVariant;
   i, c , cc : Integer;
begin
  StatusBar1.Panels[1].Text := MinimizeName(FN,StatusBar1.Canvas,StatusBar1.Panels[1].Width-4);
  Gauge.Position := 0;
  try
     WA := CreateOLEObject('Word.Application');
  except
     Windows.MessageBox(self.Handle,PAnsiChar('Не могу начать работу с MS Word ('+FN+')'),'Ошибка',MB_OK+MB_ICONEXCLAMATION);
     Abort;
  end;
  try
     WA.Visible := False;
     cc := 3;     // количество просмотров документа:
                  // (1) - тело докум.; (2) - верхний колонтитул; (3)- нижний колонтитул;
     WA.Caption := 'AutoFill(2.03): fill data to Word document';
     WA.ScreenUpdating := False;
     WA.Documents.Open(FN);
     WA.ActiveWindow.View.Type := 3 { wdPageView };
     // если колонтитулы первой страницы отличаются от остальных, то на два прохода больше:
     // (1) - тело докум.; (2) - верхний колонтитул 1 стр.; (3)- нижний колонтитул 1 стр.;
     // (4) - верхний колонтитул со 2-й стр.; (5) - нижний колонтитул со 2-й стр.
     if WA.ActiveDocument.PageSetup.DifferentFirstPageHeaderFooter then Inc(cc,2);
     Gauge.Max :=DS.FieldCount * cc;
     for c:=1 to cc do
     begin
       case c of
         1: WA.ActiveWindow.ActivePane.View.SeekView := wdSeekMainDocument;
         2: WA.ActiveWindow.ActivePane.View.SeekView := wdSeekCurrentPageHeader;
         3: WA.ActiveWindow.ActivePane.View.SeekView := wdSeekCurrentPageFooter;
         4: begin
              try   // если в документе колонтитулы не различаются, то возникает ошибка
                WA.ActiveWindow.ActivePane.View.SeekView := wdSeekCurrentPageHeader;
                WA.ActiveWindow.ActivePane.View.NextHeaderFooter;
              except
                continue;   // нет колонтитулов - и не надо ...
              end;
            end;
         5: begin
              try   // см. выше ( = 4)
                WA.ActiveWindow.ActivePane.View.SeekView := wdSeekCurrentPageFooter;
                WA.ActiveWindow.ActivePane.View.NextHeaderFooter;
              except
                continue;
              end;
            end;
         end;  //case
        for i:=0 to DS.FieldCount-1 do
        begin
          WA.Selection.Find.ClearFormatting;
          WA.Selection.Find.Replacement.ClearFormatting;
          // Сделать текст видимым после замены:
          WA.Selection.Find.Replacement.Font.Hidden := False;
          WA.Selection.Find.Text := '{<'+DS.Fields[i].FieldName+'>}';
          WA.Selection.Find.Replacement.Text := DS.Fields[i].AsString;
          WA.Selection.Find.Forward := True;
          WA.Selection.Find.Wrap := 1 { wdFindContinue };
          // если ищем скрытый текст (т.е. по формату):
          WA.Selection.Find.Format := True;
          WA.Selection.Find.MatchCase := False;
          WA.Selection.Find.MatchWholeWord := False;
          WA.Selection.Find.MatchWildCards := False;
          WA.Selection.Find.MatchSoundsLike := False;
          WA.Selection.Find.MatchAllWordForms := False;
          WA.Selection.Find.Execute(Replace := 2 { wdReplaceAll } );
          Gauge.StepIt;
          Application.ProcessMessages;
        end;
      end;    //  for c
      WA.ActiveWindow.ActivePane.View.SeekView := wdSeekMainDocument;
      try
        WA.ActiveDocument.Save;
      except
        raise Exception.Create('Не могу сохранить документ '+FN+#13#10+'Изменения не будут записаны');
      end;
  finally
     WA.ActiveDocument.Close;
     WA.ScreenUpdating := True;
     WA.Quit;
  end;
end;
}
end;
{$ENDIF}
{$IFDEF UNIX}
begin
  ShowMessage('EXPECTED SOON... Format(): '+TargetFile);
  Result := True;
end;
{$ENDIF}


end.

