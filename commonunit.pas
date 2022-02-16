unit CommonUnit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

resourcestring
  AppHeader = 'Auto Format';

const

     wdSeekMainDocument       =0;
     wdSeekPrimaryHeader      =1;
     wdSeekFirstPageHeader    =2;
     wdSeekEvenPagesHeader    =3;
     wdSeekPrimaryFooter      =4;
     wdSeekFirstPageFooter    =5;
     wdSeekEvenPagesFooter    =6;
     wdSeekFootnotes          =7;
     wdSeekEndnotes           =8;
     wdSeekCurrentPageHeader  =9;
     wdSeekCurrentPageFooter  =10;
     //--
     wdFindStop=0;          // .Wrap =  stop if reached end(begin) document
     wdFindContinue=1;      // .Wrap =  continue seek from begin(end) document


type
  {TUserRec}
  TUserRec = class(TObject)
    id     : integer;
    name   : string;
    super  : boolean;
    project: integer;
    public
      procedure Clear;
  end;

  {TBlock}
  TBlock = class(TObject)
    id     : integer;
    order  : integer;    // deprecated
    name   : string;
    info   : string;
    public
      procedure Clear;
      procedure SetBlockData(const bid:integer=-1;const bord:integer=0; const bname:string=''; const binfo:string='');
  end;

  {TPrjRec}
  TPrjRec = class(TObject)
    id         : integer;
    created    : TDate;
    modified   : TDate;
    prjinfo: string;
    tmp    : boolean;      // integer if file size ?
    public
      procedure Clear;
      procedure SetPrj(pid:integer=-1;cdate:TDate=0;mdate:TDate=0;pinfo:string='';ptmp:boolean=False);
  end;

  {TTemplate}
  TTemplate = class(TObject)
    id      : integer;
    name    : String;
    uid     : String;
    //prjid   : integer;  // ??
    //tmllen  : integer;  //??
    public
      procedure Clear;
      procedure SetTmp(tid:integer=-1;tname:string='';tuid:string='');
  end;


implementation

uses StrUtils, LCLType, LoginFrm, ListFrm, GetFileFrm;

{TUserRec}
procedure TUserRec.Clear;
begin
  id := -1;
  name := '';
  super := False;
  project := -1;
end;

//--------------------

{TBlock}
procedure TBlock.Clear;
begin
  self.SetBlockData();
end;

procedure TBlock.SetBlockData(const bid:integer=-1;const bord:integer=0; const bname:string=''; const binfo:string='');
begin
  id := bid;
  order := bord;
  name := bname;
  info := binfo;
end;
//--------------------

{TPrjRec}
procedure TPrjRec.Clear;
begin
  self.SetPrj();
end;

procedure TPrjRec.SetPrj(pid:integer=-1;cdate:TDate=0;mdate:TDate=0;pinfo:string='';ptmp:boolean=False);
begin
  self.id := pid;
  self.created  := cdate;
  self.modified := mdate;
  self.prjinfo := pinfo;
  self.tmp := ptmp;
end;

//--------------------

{TTemplate}
procedure TTemplate.Clear;
begin
  self.SetTmp();
end;

procedure TTemplate.SetTmp(tid:integer=-1;tname:string='';tuid:string='');
begin
  self.id   := tid;
  self.name := tname;
  self.uid  := tuid;
end;

//--------------------
//--------------------
{
unit afmain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, EditBtn, StdCtrls;

const

     wdSeekMainDocument       =0;
     wdSeekPrimaryHeader      =1;
     wdSeekFirstPageHeader    =2;
     wdSeekEvenPagesHeader    =3;
     wdSeekPrimaryFooter      =4;
     wdSeekFirstPageFooter    =5;
     wdSeekEvenPagesFooter    =6;
     wdSeekFootnotes          =7;
     wdSeekEndnotes           =8;
     wdSeekCurrentPageHeader  =9;
     wdSeekCurrentPageFooter  =10;

     //--
     wdFindStop=0;          // .Wrap =  stop if reached end(begin) document
     wdFindContinue=1;      // .Wrap =  continue seek from begin(end) document


type

  { TReplaceField }
  TReplaceField = class(TObject)
    SeekSection : integer;
    SeekStr : string;
  public
    constructor Create(idx:integer=-1; sstr:string='');
  end;

  { TMainForm }

  TMainForm = class(TForm)
    EditTextButton: TButton;
    CheckBox1: TCheckBox;
    FormatButton: TButton;
    GroupBox1: TGroupBox;
    FileNameEdit1: TFileNameEdit;
    FileNameEdit2: TFileNameEdit;
    Label1: TLabel;
    Label2: TLabel;
    ListBox1: TListBox;
    ScanButton: TButton;
    StaticText1: TStaticText;
    procedure EditTextButtonClick(Sender: TObject);
    procedure FormatButtonClick(Sender: TObject);
    procedure ListBox1SelectionChange(Sender: TObject; User: boolean);
    procedure ScanButtonClick(Sender: TObject);
  private

  public
    procedure ScanFile(FN:string);
    procedure FormatFile(FN:string);
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

//TODO: 1) расширение файла по умолчанию;
//      2) начальный каталог для файлов
//      3) поле замены - многострочное - ???
//      4) формат замены

uses ComObj, FileUtil, LCLType;

{ TReplaceField }
constructor TReplaceField.Create(idx:integer=-1; sstr:string='');
begin
  inherited Create;
  self.SeekSection := idx;
  self.SeekStr := sstr;
end;

{ TMainForm }

procedure TMainForm.ScanButtonClick(Sender: TObject);
begin
  if not FileExists(FileNameEdit1.FileName) then
  begin
    MessageDlg('Ошибка','Файл шаблона выбран неверно',mtError,[mbYes],'');
    Exit;
  end;
  ScanFile(FileNameEdit1.FileName);
end;

procedure TMainForm.FormatButtonClick(Sender: TObject);
begin
  if not FileExists(FileNameEdit1.FileName) then
  begin
    MessageDlg('Ошибка','Файл шаблона выбран неверно',mtError,[mbYes],'');
    Exit;
  end;
  if FileExists(FileNameEdit2.FileName) then
    if MessageDlg('Подтверждение','Файл результата уже существует. Перезаписать его?',mtConfirmation,[mbYes,mbNo],'')<>mrYes then Exit;
  if ListBox1.Items.Count<1 then
  begin
    MessageDlg('Ошибка','Нет информации для форматирования (список пуст)',mtError,[mbOk],'');
    Exit;
  end;
  CopyFile(FileNameEdit1.FileName,FileNameEdit2.FileName);
  FormatFile(FileNameEdit2.FileName);
end;

procedure TMainForm.EditTextButtonClick(Sender: TObject);
var
  r : TReplaceField;
  ii : integer;
  s : string;
begin
  ii := ListBox1.ItemIndex;
  if ii<0 then Exit;
  r := TReplaceField(ListBox1.Items.Objects[ListBox1.ItemIndex]);
  s:=InputBox('Вводите новое значение для:', r.SeekStr,'');
  if s<>r.SeekStr then
  begin
    r.SeekStr:=s;
    ListBox1.Items.Objects[ListBox1.ItemIndex] := r;
    StaticText1.Caption:=s;
  end;
end;

procedure TMainForm.ListBox1SelectionChange(Sender: TObject; User: boolean);
begin
  if ListBox1.ItemIndex<0 then Exit;
  StaticText1.Caption := TReplaceField(ListBox1.Items.Objects[ListBox1.ItemIndex]).SeekStr;
end;

procedure TMainForm.ScanFile(FN:string);
var
   WA : OleVariant;
   i, c , cc : Integer;
   docycle : boolean;
begin
  try
     WA := CreateOLEObject('Word.Application');
  except
     MessageDlg('Ошибка','Не могу начать работу с MS Word ('+FN+')',mtError,[mbOk],'');
     Exit;
  end;
  //****
  ListBox1.Clear;
  try
     WA.Visible := False;
     WA.Caption := 'AutoFill: fill data to Word document';
     WA.ScreenUpdating := False;
     WA.Documents.Open(FN);
     WA.ActiveWindow.View.&Type := 3 { wdPageView };
     for c:=0 to 8 do  // 9 и 10 - не используются?
     begin
       // если флаг "колонтитул первой страницы" НЕ установлен, пропустить 2 и 5
       if not WA.ActiveDocument.PageSetup.DifferentFirstPageHeaderFooter and
          ((c = wdSeekFirstPageFooter) or (c = wdSeekFirstPageHeader)) then continue;
       // если флаг "различать колонтитулы четных и нечетных страниц" НЕ установлен, пропустить 3 и 6
       if not WA.Activedocument.PageSetup.OddAndEvenPagesHeaderFooter and
          ((c = wdSeekEvenPagesHeader) or (c = wdSeekEvenPagesFooter)) then continue;
       //
       docycle:=True;
       try
         WA.ActiveWindow.View.SeekView := c;
         //WA.ActiveWindow.ActivePane.View.SeekView := c;
       except
         // скорее всего, такой секции нет в документе
         continue;
       end;
       while docycle do
       begin
         WA.Selection.Find.ClearFormatting;
         WA.Selection.Find.Text :=  '\{\<*\>\}';       //'\{\<Block([0-9]@)\>\}';
         WA.Selection.Find.MatchWildcards := True; // принимать знаки * ? как спецсимволы
         WA.Selection.Find.Forward := True;
         WA.Selection.Find.Wrap := wdFindStop; // останавливаться в конце документа(не начинать сначала)
         WA.Selection.Find.Format := False;
         WA.Selection.Find.MatchCase := False;
         WA.Selection.Find.MatchWholeWord := False;
         WA.Selection.Find.MatchSoundsLike := False;
         WA.Selection.Find.MatchAllWordForms := False;
         docycle := WA.Selection.Find.Execute;
         if docycle then
            ListBox1.Items.AddObject(WA.Selection.Text,TReplaceField.Create(c,WA.Selection.Text));
         Application.ProcessMessages;
       end;
    end;  //  for c
    WA.ActiveWindow.ActivePane.View.SeekView := Integer(wdSeekMainDocument);
    showmessage('Сканирование документа завершено');
  finally
     WA.ActiveDocument.Close;
     WA.ScreenUpdating := True;
     WA.Quit;
  end;
end;


procedure TMainForm.FormatFile(FN:string);
var
   WA : OleVariant;
   i, c , cc : Integer;
   docycle : boolean;
begin
  try
    try
      WA := CreateOLEObject('Word.Application');
    except
      MessageDlg('Ошибка','Не могу начать работу с MS Word ('+FN+')',mtError,[mbOk],'');
      Abort;
    end;
    WA.Visible := True; //False;
    cc := 3;     // количество просмотров документа:
                  // (1) - тело докум.; (2) - верхний колонтитул; (3)- нижний колонтитул;
    WA.Caption := 'AutoFill: fill data to Word document';
    WA.ScreenUpdating := True; //False;
    WA.Documents.Open(FN);
    WA.ActiveWindow.View.&Type := 3 { wdPageView };
    for c:=0 to 8 do  // 9 и 10 - не используются?
    begin
      // если флаг "колонтитул первой страницы" НЕ установлен, пропустить 2 и 5
      if not WA.ActiveDocument.PageSetup.DifferentFirstPageHeaderFooter and
         ((c = wdSeekFirstPageFooter) or (c = wdSeekFirstPageHeader)) then continue;
      // если флаг "различать колонтитулы четных и нечетных страниц" НЕ установлен, пропустить 3 и 6
      if not WA.Activedocument.PageSetup.OddAndEvenPagesHeaderFooter and
         ((c = wdSeekEvenPagesHeader) or (c = wdSeekEvenPagesFooter)) then continue;
      //
      docycle:=True;
      try
        WA.ActiveWindow.View.SeekView := c;
        //WA.ActiveWindow.ActivePane.View.SeekView := c;
      except
        // скорее всего, такой секции нет в документе
        continue;
      end;
      for i:=0 to ListBox1.Items.Count-1 do
      begin
        if not Assigned(ListBox1.Items.Objects[i]) then continue;
        if c <> TReplaceField(ListBox1.Items.Objects[i]).SeekSection then continue;
        WA.Selection.Find.ClearFormatting;
        WA.Selection.Find.Text := ListBox1.Items[i];
        WA.Selection.Find.Replacement.Text := TReplaceField(ListBox1.Items.Objects[i]).SeekStr;
        WA.Selection.Find.Forward := True;
        WA.Selection.Find.Wrap := wdFindStop;
        //WA.Selection.Find.Format := True;
        WA.Selection.Find.Format := False;
        WA.Selection.Find.MatchCase := False;
        WA.Selection.Find.MatchWildCards := False;
        WA.Selection.Find.MatchWholeWord := False;
        WA.Selection.Find.MatchSoundsLike := False;
        WA.Selection.Find.MatchAllWordForms := False;
        WA.Selection.Find.Execute(Replace := 2 { wdReplaceAll } );
        Application.ProcessMessages;
      end;
    end; //  for c
    WA.ActiveWindow.ActivePane.View.SeekView := wdSeekMainDocument;
    try
      WA.ActiveDocument.Save;
      showmessage('Document saved');
    except
      raise Exception.Create('Не могу сохранить документ '+FN+#13#10+'Изменения не будут записаны');
    end;
  finally
     WA.ActiveDocument.Close;
     WA.ScreenUpdating := True;
     WA.Quit;
  end;
end;

{
procedure TMainForm.ScanFile(FN:string);
var
   WA : OleVariant;
   i, c , cc : Integer;
   docycle : boolean;
begin
  try
     WA := CreateOLEObject('Word.Application');
  except
     MessageDlg('Ошибка','Не могу начать работу с MS Word ('+FN+')',mtError,[mbOk],'');
     Exit;
  end;
  ListBox1.Clear;
  try
     WA.Visible := False;
     // количество просмотров документа:
     // (1) - тело докум.; (2) - верхний колонтитул; (3)- нижний колонтитул;
     if CheckBox1.Checked then cc := 3
     else cc := 1;
     WA.Caption := 'AutoFill: fill data to Word document';
     WA.ScreenUpdating := False;
     WA.Documents.Open(FN);
     WA.ActiveWindow.View.&Type := 3 { wdPageView };
     // если колонтитулы первой страницы отличаются от остальных, то на два прохода больше:
     // (1) - тело докум.; (2) - верхний колонтитул 1 стр.; (3)- нижний колонтитул 1 стр.;
     // (4) - верхний колонтитул со 2-й стр.; (5) - нижний колонтитул со 2-й стр.
     if WA.ActiveDocument.PageSetup.DifferentFirstPageHeaderFooter then Inc(cc,2);
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
       docycle:=True;
       while docycle do
       begin
         WA.Selection.Find.ClearFormatting;
         {
           With Selection.Find
            .Text = "\{\<*\>\}"
            .Replacement.Text = ""
            .Forward = True
            .Wrap = wdFindContinue
            .Format = False
            .MatchCase = False
            .MatchWholeWord = False
            .MatchAllWordForms = False
            .MatchSoundsLike = False
            .MatchWildcards = True
           End With
         }
  //       WA.Selection.Find.Replacement.ClearFormatting;
         // Сделать текст видимым после замены:
 //        WA.Selection.Find.Replacement.Font.Hidden := False;
         WA.Selection.Find.Text := '\{\<*\>\}';
         WA.Selection.Find.MatchWildcards := True; // принимать знаки * ? как спецсимволы
//         WA.Selection.Find.Replacement.Text := 'WWWWWWWWWWWWWWWWWWWWWW';
         WA.Selection.Find.Forward := True;
         WA.Selection.Find.Wrap := wdFindStop; // останавливаться в конце документа(не начинать сначала)
         // если ищем скрытый текст (т.е. по формату):
         //         WA.Selection.Find.Format := True;
         WA.Selection.Find.Format := False;
         WA.Selection.Find.MatchCase := False;
         WA.Selection.Find.MatchWholeWord := False;
         WA.Selection.Find.MatchSoundsLike := False;
         WA.Selection.Find.MatchAllWordForms := False;
         docycle := WA.Selection.Find.Execute;
         if docycle then
            ListBox1.Items.Add('Block');
         Application.ProcessMessages;
       end;
       { for i:=0 to DS.FieldCount-1 do
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
      end;
      }
    end;  //  for c
    WA.ActiveWindow.ActivePane.View.SeekView := wdSeekMainDocument;
    showmessage('Сканирование документа завершено');
  finally
     WA.ActiveDocument.Close;
     WA.ScreenUpdating := True;
     WA.Quit;
  end;
end;

}

{
procedure TMainForm.FormatFile(FN:string);
var
   WA : OleVariant;
   i, c , cc : Integer;
   docycle : boolean;
begin
  try
     WA := CreateOLEObject('Word.Application');
  except
     MessageDlg('Ошибка','Не могу начать работу с MS Word ('+FN+')',mtError,[mbOk],'');
     Abort;
  end;
  ListBox1.Clear;
  try
     WA.Visible := False;
     cc := 3;     // количество просмотров документа:
                  // (1) - тело докум.; (2) - верхний колонтитул; (3)- нижний колонтитул;
     WA.Caption := 'AutoFill: fill data to Word document';
     WA.ScreenUpdating := False;
     WA.Documents.Open(FN);
     WA.ActiveWindow.View.&Type := 3 { wdPageView };
     // если колонтитулы первой страницы отличаются от остальных, то на два прохода больше:
     // (1) - тело докум.; (2) - верхний колонтитул 1 стр.; (3)- нижний колонтитул 1 стр.;
     // (4) - верхний колонтитул со 2-й стр.; (5) - нижний колонтитул со 2-й стр.
     {
      wdSeekCurrentPageFooter	10	The current page footer.
      wdSeekCurrentPageHeader	9	The current page header.
      wdSeekEndnotes	8	Endnotes.
      wdSeekEvenPagesFooter	6	The even pages footer.
      wdSeekEvenPagesHeader	3	The even pages header.
      wdSeekFirstPageFooter	5	The first page footer.
      wdSeekFirstPageHeader	2	The first page header.
      wdSeekFootnotes	7	Footnotes.
      wdSeekMainDocument	0	The main document.
      wdSeekPrimaryFooter	4	The primary footer.
      wdSeekPrimaryHeader	1	The primary header.
     }
     if WA.ActiveDocument.PageSetup.DifferentFirstPageHeaderFooter then Inc(cc,2);
     for c:=1 to cc do
     begin
       case c of
         1: WA.ActiveWindow.ActivePane.View.SeekView := Integer(wdSeekMainDocument);
         2: WA.ActiveWindow.ActivePane.View.SeekView := Integer(wdSeekCurrentPageHeader);
         3: WA.ActiveWindow.ActivePane.View.SeekView := Integer(wdSeekCurrentPageFooter);
         4: begin
              try   // если в документе колонтитулы не различаются, то возникает ошибка
                WA.ActiveWindow.ActivePane.View.SeekView := Integer(wdSeekCurrentPageHeader);
                WA.ActiveWindow.ActivePane.View.NextHeaderFooter;
              except
                continue;   // нет колонтитулов - и не надо ...
              end;
            end;
         5: begin
              try   // см. выше ( = 4)
                WA.ActiveWindow.ActivePane.View.SeekView := Integer(wdSeekCurrentPageFooter);
                WA.ActiveWindow.ActivePane.View.NextHeaderFooter;
              except
                continue;
              end;
            end;
         end;  //case
       docycle:=True;
       while docycle do
       begin
         WA.Selection.Find.ClearFormatting;
         {
           With Selection.Find
            .Text = "\{\<*\>\}"
            .Replacement.Text = ""
            .Forward = True
            .Wrap = wdFindContinue
            .Format = False
            .MatchCase = False
            .MatchWholeWord = False
            .MatchAllWordForms = False
            .MatchSoundsLike = False
            .MatchWildcards = True
           End With
         }
  //       WA.Selection.Find.Replacement.ClearFormatting;
         // Сделать текст видимым после замены:
 //        WA.Selection.Find.Replacement.Font.Hidden := False;
         WA.Selection.Find.Text := '\{\<*\>\}';
//         WA.Selection.Find.Replacement.Text := 'WWWWWWWWWWWWWWWWWWWWWW';
         WA.Selection.Find.Forward := True;
         WA.Selection.Find.Wrap := wdFindStop;
         // если ищем скрытый текст (т.е. по формату):
//         WA.Selection.Find.Format := True;
           WA.Selection.Find.Format := False;
           WA.Selection.Find.MatchCase := False;
           WA.Selection.Find.MatchWildcards := True;
           WA.Selection.Find.MatchWholeWord := False;
//         WA.Selection.Find.MatchWildCards := False;
         WA.Selection.Find.MatchSoundsLike := False;
         WA.Selection.Find.MatchAllWordForms := False;
         docycle := WA.Selection.Find.Execute;
         if docycle then
            ListBox1.Items.Add('Block');
       end;
       { for i:=0 to DS.FieldCount-1 do
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
      }
      WA.ActiveWindow.ActivePane.View.SeekView := Integer(wdSeekMainDocument);
      try
        WA.ActiveDocument.Save;
        showmessage('Document saved');
      except
        raise Exception.Create('Не могу сохранить документ '+FN+#13#10+'Изменения не будут записаны');
      end;
    end;
  finally
     WA.ActiveDocument.Close;
     WA.ScreenUpdating := True;
     WA.Quit;
  end;
end;

}
{
 wdSeekCurrentPageFooter	10	The current page footer.
 wdSeekCurrentPageHeader	9	The current page header.
 wdSeekEndnotes	8	Endnotes.
 wdSeekEvenPagesFooter	6	The even pages footer.
 wdSeekEvenPagesHeader	3	The even pages header.
 wdSeekFirstPageFooter	5	The first page footer.
 wdSeekFirstPageHeader	2	The first page header.
 wdSeekFootnotes	7	Footnotes.
 wdSeekMainDocument	0	The main document.
 wdSeekPrimaryFooter	4	The primary footer.
 wdSeekPrimaryHeader	1	The primary header.
}

{
Sub UpdateAllFields()
  Application.ScreenUpdating = False 'Отключение обновления экрана
  ActiveDocument.PrintPreview 'Предварительный просмотр
  ActiveDocument.ClosePrintPreview 'Закрыть предварительный просмотр
  Application.ScreenUpdating = True 'Обновить экран
End Sub
}
{
' WORD (WO) находит текст (p) и меняет его на (t)
' Dim WO As Object = CreateObject("Excel.Application")
' StoryRanges - коллекция блоков документа (осн.док, колонтитулы, сноски, примечания и т.п.)

    Private Sub ZamText(ByVal WO As Object, ByVal p As String, ByVal t As String)
        Dim Story As Object
        For Each Story In WO.Selection.Document.StoryRanges
            Do
                With Story.Find
                    .Text = p : .Replacement.Text = t
                    .Wrap = 1 : .Execute(Replace:=2)
                End With
                Story = Story.NextStoryRange
            Loop While Not Story Is Nothing
        Next
    End Sub
}

{
объект ActiveDocument.PageSetup:
Свойство OddAndEvenPagesHeaderFooter показывает, различаются ли колонтитулы чётных и нечётных страниц:
=True (-1::Longint) - Да, различаются
=False (0::Longint) - Нет
DifferentFirstPageHeaderFooter - отличается ли колонтитул первой страницы
=True (-1::Longint) - Да
=False (0::Longint) - Нет
}

end.


}
//--------------------

end.

