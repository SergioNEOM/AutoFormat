unit mainform;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqlite3conn, sqldb, Forms, Controls, Graphics, Dialogs,
  StdCtrls, ActnList, Menus, DM;

resourcestring
  AppHeader = 'Auto Format';

type

  {TUserRec}
  TUserRec = class
    id     : integer;
    name   : string;
    super  : boolean;
    project: integer;
    public
      procedure Clear;
  end;

  {TBlock}
  TBlock = class
    id     : integer;
    order  : integer;
    name   : string;
    info   : string;
    public
      procedure Clear;
  end;

  { TMainForm1 }

  TMainForm1 = class(TForm)
    FormatAction: TAction;
    ListBox1: TListBox;
    MainMenu1: TMainMenu;
    MenuItem1: TMenuItem;
    MenuItem2: TMenuItem;
    MenuItem3: TMenuItem;
    MenuItem4: TMenuItem;
    MenuItem5: TMenuItem;
    MenuItem6: TMenuItem;
    MenuItem7: TMenuItem;
    N2: TMenuItem;
    N1: TMenuItem;
    OpenPrjAction: TAction;
    NewPrjAction: TAction;
    ExitAppAction: TAction;
    ChangeUserAction: TAction;
    ActionList1: TActionList;
    ImageList1: TImageList;
    procedure ChangeUserActionExecute(Sender: TObject);
    procedure ExitAppActionExecute(Sender: TObject);
    procedure FormatActionExecute(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure OpenPrjActionExecute(Sender: TObject);
  private
    AppStarted : boolean;
    procedure FillConfig;
  public
    DBFile    : string;
    CurrentUser  : TUserRec;
    CurrentBlock : TBlock;
    procedure ShowLogin;
    function Format(prj: integer; TargetFile: Widestring): boolean;
  end;

var
  MainForm1: TMainForm1;

implementation

{$R *.lfm}
uses ComObj, StrUtils, LCLType,
  LoginFrm, ListFrm;

{TBlock}
procedure TBlock.Clear;
begin
  id := -1;
  order := 0;
  name := '';
  info := '';
end;

//--------------------

{TUserRec}
procedure TUserRec.Clear;
begin
  id := -1;
  name := '';
  super := False;
  project := -1;
end;

//--------------------

procedure TMainForm1.FormCreate(Sender: TObject);
begin
  AppStarted:=True;
  CurrentUser := TUserRec.Create;
  CurrentUser.Clear;
  CurrentBlock := TBlock.Create;
  CurrentBlock.Clear;
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
    AppStarted:=False;
    FillConfig;
    //---
    DM1.DBConnect;
    //---
    ShowLogin;
  end;
end;

procedure TMainForm1.OpenPrjActionExecute(Sender: TObject);
begin
  if CurrentUser.id <=0 then Exit;
  // prepare SQLQuery
  with DM1.SQLQuery1 do
  begin
    Close;
    SQL.Text:='SELECT * FROM projects where user_id=:u';
    ParamByName('u').Value:=CurrentUser.id;
    try
      Open;
    except
      Application.MessageBox('projects list error','ERROR',MB_ICONERROR+MB_OK);
    end;
  end;
  //--
  with TListForm1.Create(self,DM1.DataSource1,'Проекты',CurrentUser.project) do
  try
     if ShowModal = mrOk then
     begin
       CurrentUser.project:=DM1.DataSource1.DataSet.FieldByName('id').AsInteger;
       // project parameters...
     end;
  finally
    Free;
  end;
end;

procedure TMainForm1.FillConfig;
begin
  DBFile :=  Application.GetOptionValue('d','dbfile');
  if IsEmptyStr(DBFile,[' ']) then
    DBFile := ExtractFilePath(Application.ExeName)+ExtractFileName(Application.ExeName)+'.db';
  //
  DBFile:= ExpandFileName(DBFile);
  if not FileExists(DBFile) then
  begin
    Application.MessageBox('Не найден файл БД! '+#13#10+'Приложение будет закрыто.','Ошибка',MB_ICONERROR+MB_OK);
    Close;
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
const
  prefix = '{<block';
  suffix = '>}';
var
     WA : OleVariant;
     c, cc, i : integer;
     SeekStr, ReplStr : WideString;
begin
  ShowMessage('Format: '+TargetFile);
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
      showmessage('111 save');
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

end.

