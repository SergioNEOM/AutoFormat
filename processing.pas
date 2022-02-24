unit Processing;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs,
  ComCtrls, Buttons, StdCtrls, contnrs {for TObjectList},
  CommonUnit;

type

  { TTaskForm }

  TTaskForm = class(TForm)
    BitBtn1: TBitBtn;
    ProgressBar1: TProgressBar;
    StaticText1: TStaticText;
    procedure BitBtn1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    CanDo : boolean;
    WPrj,
    WType : integer;
    WParam : string;
    function WordFormat(prj: integer; TargetFile: Widestring): boolean;
    procedure OtherFormat(TargetFile: Widestring);
  public
    blk : TBlock;
    constructor Create(TheOwner:TComponent; prj_id : integer; WorkParam:string=''; WorkType: integer=0);
    function WordScanFile(FN:string): TStringList;
    function Format(prj: integer; TargetFile: Widestring; FileType:integer=0): boolean;
  end;

var
  TaskForm: TTaskForm;

implementation

{$R *.lfm}


uses
    {$IFDEF WINDOWS} ComObj, {$ENDIF}
    StrUtils;

constructor TTaskForm.Create(TheOwner:TComponent; prj_id : integer; WorkParam:string=''; WorkType: integer=0);
begin
  inherited Create(TheOwner);
  WPrj:=prj_id;
  WType:=WorkType;
  WParam:=WorkParam;
end;

procedure TTaskForm.FormCreate(Sender: TObject);
begin
  // CanDo :=  (WType>0) and (WParam<>''); WType=TASK_TEST ??
  CanDo := True;
end;

procedure TTaskForm.FormShow(Sender: TObject);
begin
  case WType of
    TASK_TEST       : OtherFormat(WParam);
    TASK_WORD_SCAN  : WordScanFile(WParam);
    TASK_WORD_WRITE : WordFormat(WPrj,WParam);
  end;

  if CanDo then ModalResult := mrOk
  else ModalResult:=mrCancel;

end;

function TTaskForm.Format(prj: integer; TargetFile: Widestring; FileType:integer=0): boolean;
begin
  case FileType of
    0: WordFormat(prj,TargetFile);
    //1: coming soon...
    else OtherFormat(TargetFile);
  end;
end;


procedure TTaskForm.BitBtn1Click(Sender: TObject);
begin
  CanDo:=False;
end;

function TTaskForm.WordScanFile(FN:string) :TStringList;
{$IFDEF WINDOWS}
var
   WA : OleVariant;
   i, c , cc : Integer;
   docycle : boolean;
   blks : TStringList;
begin
  blks := nil;
  try
     WA := CreateOLEObject('Word.Application');
  except
     MessageDlg('Ошибка','Не могу начать работу с MS Word ('+FN+')',mtError,[mbOk],'');
     Exit;
  end;
  //****
  try
    blks := TStringList.Create;
    WA.Visible := False;
    WA.Caption := 'AutoFormat: scan Word document';
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

        if docycle then  blks.Add(WA.Selection.Text);

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
  Result := blks;
end;
{$ELSE}
begin
  ShowMessage('Function "WordScanFile" can only work in the Windows');
end;
{$ENDIF}


//----
function TTaskForm.WordFormat(prj: integer; TargetFile: WideString): boolean;
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
     MessageDlg('Ошибка','Не могу начать работу с MS Word ('+TargetFile+')',mtError,[mbOK],'');
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
      if not CanDo then  Exit; // finally -> WA.Quit
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
        if not CanDo then  Exit; // finally -> WA.Quit

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
      WA.ActiveDocument.Close;
      Result := True;
      showmessage('Document saved'); //TODO: Application.MessageBox
    except
      raise Exception.Create('Не могу сохранить документ '+TargetFile+#13#10+'Изменения не будут записаны');
    end;
  finally
    WA.ScreenUpdating := True;
    WA.Quit;
  end;
  {
  procedure TTaskForm.MakeDocs(FN: String; DS:TDataSet);
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
{$ELSE}
begin
  ShowMessage('Function "WordFormat" can only work in the Windows');
end;
{$ENDIF}
//=============== end of WordFormat ========================

procedure TTaskForm.OtherFormat(TargetFile: Widestring);
begin
  ShowMessage('Format file of '#13#10+TargetFile+#13#10' isn''t recognized!');
  CanDo := False;
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

}


end.

