unit CommonUnit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,ComCtrls;

resourcestring
  AppHeader = 'Auto Format';
  MyChars   = 'SVS';

const
     USER_ROLE_NONE    = 0;
     USER_ROLE_DEFAULT = 1;
     USER_ROLE_CREATOR = 99;
     USER_ROLE_ADMIN   = 999;
     //
     TASK_TEST       = 0;
     TASK_WORD_SCAN  = 1;
     TASK_WORD_WRITE = 2;
     //
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
    private
      ur_id     : integer;
      ur_name   : string;
      ur_super  : boolean;
      ur_project: integer;
    public
      property Id : integer read ur_id write ur_id;
      property Name : String read ur_name write ur_name;
      property Super  : boolean read ur_super write ur_super;
      property Project: integer read ur_project write ur_project;
      //
      procedure Clear;
  end;

  {TBlock}
  TBlock = class(TObject)
    id     : integer;
    order  : integer;    // deprecated
    name   : string;
    info   : string;
    public
      constructor Create(const bid:integer=-1;const bord:integer=0; const bname:string=''; const binfo:string='');
      procedure Clear;
      procedure SetBlockData(const bid:integer=-1;const bord:integer=0; const bname:string=''; const binfo:string='');
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

  function HashPass(pass:string):string;
  function WordScan2DB(tmp_id:integer; FN:string; Gauge: TProgressBar=nil):integer;
  function WordWrite(fname: string; tmp_id:integer):boolean;

implementation

uses
  {$IFDEF WINDOWS} ComObj, {$ENDIF}
  LCLType, md5, Dialogs, DM;


function HashPass(pass: string): string;
begin
  Result := MD5Print(MD5String(MyChars+Trim(pass)+MyChars));
end;

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
constructor TBlock.Create(const bid:integer=-1;const bord:integer=0; const bname:string=''; const binfo:string='');
begin
  inherited Create;
  self.SetBlockData(bid,bord,bname,binfo);
end;

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
function WordScan2DB(tmp_id:integer;FN:string; Gauge: TProgressBar=nil):integer;
{$IFDEF WINDOWS}
var
   WA : OleVariant;
   i, c , cc : Integer;
   docycle : boolean;
begin
  Result := 0;       // on exit - counted blocks
  try
     WA := CreateOLEObject('Word.Application');
  except
     MessageDlg('????????????','???? ???????? ???????????? ???????????? ?? MS Word ('+FN+')',mtError,[mbOk],'');
     Exit;
  end;
  //****
  if Assigned(Gauge) then Gauge.Position:=0;
  try
    WA.Visible := False;
    WA.Caption := 'AutoFormat: scan Word document';
    WA.ScreenUpdating := False;
    WA.Documents.Open(FN);
    WA.ActiveWindow.View.&Type := 3 { wdPageView };
    docycle:=True;
    if Assigned(Gauge) then Gauge.Max:=8;
    for c:=0 to 8 do  // 9 ?? 10 - ???? ?????????????????????????
    begin
      if Assigned(Gauge) then Gauge.Position:=c; //TODO: Gauge.StepIt;
      if not docycle then break;
      // ???????? ???????? "???????????????????? ???????????? ????????????????" ???? ????????????????????, ???????????????????? 2 ?? 5
      if not WA.ActiveDocument.PageSetup.DifferentFirstPageHeaderFooter and
          ((c = wdSeekFirstPageFooter) or (c = wdSeekFirstPageHeader)) then continue;
      // ???????? ???????? "?????????????????? ?????????????????????? ???????????? ?? ???????????????? ??????????????" ???? ????????????????????, ???????????????????? 3 ?? 6
      if not WA.Activedocument.PageSetup.OddAndEvenPagesHeaderFooter and
          ((c = wdSeekEvenPagesHeader) or (c = wdSeekEvenPagesFooter)) then continue;
      //
      try
        WA.ActiveWindow.View.SeekView := c;
        //WA.ActiveWindow.ActivePane.View.SeekView := c;
      except
        // ???????????? ??????????, ?????????? ???????????? ?????? ?? ??????????????????
        continue;
      end;
      while docycle do
      begin
        WA.Selection.Find.ClearFormatting;
        WA.Selection.Find.Text :=  '\{\<*\>\}';       //'\{\<Block([0-9]@)\>\}';
        WA.Selection.Find.MatchWildcards := True; // ?????????????????? ?????????? * ? ?????? ??????????????????????
        WA.Selection.Find.Forward := True;
        WA.Selection.Find.Wrap := wdFindStop; // ?????????????????????????????? ?? ?????????? ??????????????????(???? ???????????????? ??????????????)
        WA.Selection.Find.Format := False;
        WA.Selection.Find.MatchCase := False;
        WA.Selection.Find.MatchWholeWord := False;
        WA.Selection.Find.MatchSoundsLike := False;
        WA.Selection.Find.MatchAllWordForms := False;
        if not WA.Selection.Find.Execute then break;
        inc(Result);
        DM1.AddBlk2DB(tmp_id,WA.Selection.Text,Result);
        //Application.ProcessMessages;
      end; // while
    end;  //  for c
    WA.ActiveWindow.ActivePane.View.SeekView := Integer(wdSeekMainDocument);
  finally
     WA.ActiveDocument.Close;
     WA.ScreenUpdating := True;
     WA.Quit;
  end;
end;
{$ELSE}
begin
  ShowMessage('Function "WordScanFile" can only work in the Windows');
end;
{$ENDIF}


function WordWrite(fname: string; tmp_id:integer):boolean;
{$IFDEF WINDOWS}
var
   WA : OleVariant;
   i, c , cc : Integer;
   doCycle : boolean;
   seekStr, replaceStr : string;
begin
  Result := False;
  if tmp_id<=0 then Exit; //TODO: debug log
  //***---
  DM1.SQLQuery1.Close;
  DM1.SQLQuery1.SQL.Text := 'SELECT b.blockname, c.conttext FROM blocks b, content c WHERE b.tmp_id=:curtemp and c.block_id=b.id';
  DM1.SQLQuery1.ParamByName('curtemp').AsInteger := tmp_id;
  try
    DM1.SQLQuery1.Open;
    if DM1.SQLQuery1.IsEmpty then raise Exception.Create('no records to fill');
  except
    //TODO: no records to fill  -> debug log
    showmessage('content open error');
    Exit;
  end;
  //****
  try
     WA := CreateOLEObject('Word.Application');
  except
     MessageDlg('????????????','???? ???????? ???????????? ???????????? ?? MS Word ('+fname+')',mtError,[mbOk],'');
     Exit;
  end;
  //***---
  try
    WA.Visible := False;
    WA.Caption := 'AutoFormat: fill Word document';
    WA.ScreenUpdating := False;
    WA.Documents.Open(fname);
    WA.ActiveWindow.View.&Type := 3 { wdPageView };
    doCycle:=True;
    for c:=0 to 8 do  // 9 ?? 10 - ???? ?????????????????????????
    begin
      if not doCycle then break;
      // ???????? ???????? "???????????????????? ???????????? ????????????????" ???? ????????????????????, ???????????????????? 2 ?? 5
      if not WA.ActiveDocument.PageSetup.DifferentFirstPageHeaderFooter and
          ((c = wdSeekFirstPageFooter) or (c = wdSeekFirstPageHeader)) then continue;
      // ???????? ???????? "?????????????????? ?????????????????????? ???????????? ?? ???????????????? ??????????????" ???? ????????????????????, ???????????????????? 3 ?? 6
      if not WA.Activedocument.PageSetup.OddAndEvenPagesHeaderFooter and
          ((c = wdSeekEvenPagesHeader) or (c = wdSeekEvenPagesFooter)) then continue;
      //
      try
        WA.ActiveWindow.View.SeekView := c;
        //WA.ActiveWindow.ActivePane.View.SeekView := c;
      except
        // ???????????? ??????????, ?????????? ???????????? ?????? ?? ??????????????????
        continue;
      end;
      while doCycle do
      begin
        DM1.SQLQuery1.First;
        while not DM1.SQLQuery1.EOF do
        begin
          seekStr := DM1.SQLQuery1.FieldByName('blockname').AsString;
          replaceStr := DM1.SQLQuery1.FieldByName('conttext').AsString;
          //***************
          WA.Selection.Find.ClearFormatting;
          WA.Selection.Find.Text := seekStr;
          WA.Selection.Find.Replacement.Text := replaceStr;
          WA.Selection.Find.Forward := True;
          WA.Selection.Find.Wrap := wdFindStop;
          //WA.Selection.Find.Format := True;
          WA.Selection.Find.Format := False;
          WA.Selection.Find.MatchCase := False;
          WA.Selection.Find.MatchWildCards := False;
          WA.Selection.Find.MatchWholeWord := False;
          WA.Selection.Find.MatchSoundsLike := False;
          WA.Selection.Find.MatchAllWordForms := False;
          if not WA.Selection.Find.Execute(Replace := 2 { wdReplaceAll }) then doCycle:=False;
          //***************
          DM1.SQLQuery1.Next;
        end; //while not EOF
      end; // while doCycle
    end;  //  for c
    WA.ActiveWindow.ActivePane.View.SeekView := Integer(wdSeekMainDocument);
  finally
     DM1.SQLQuery1.Close;
     //***---
     WA.ActiveDocument.Close;    //TODO: ???? ?????????????? ???? ????????????, ???????? ???????? ???? ?????????????????
     WA.ScreenUpdating := True;
     WA.Quit;
  end;
end;
{$ELSE}
begin
  ShowMessage('Function "WordWrite" can only work in the Windows');
end;
{$ENDIF}



//--------------------
{

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

//TODO: 1) ???????????????????? ?????????? ???? ??????????????????;
//      2) ?????????????????? ?????????????? ?????? ????????????
//      3) ???????? ???????????? - ?????????????????????????? - ???
//      4) ???????????? ????????????

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
    MessageDlg('????????????','???????? ?????????????? ???????????? ??????????????',mtError,[mbYes],'');
    Exit;
  end;
  ScanFile(FileNameEdit1.FileName);
end;

procedure TMainForm.FormatButtonClick(Sender: TObject);
begin
  if not FileExists(FileNameEdit1.FileName) then
  begin
    MessageDlg('????????????','???????? ?????????????? ???????????? ??????????????',mtError,[mbYes],'');
    Exit;
  end;
  if FileExists(FileNameEdit2.FileName) then
    if MessageDlg('??????????????????????????','???????? ???????????????????? ?????? ????????????????????. ???????????????????????? ???????',mtConfirmation,[mbYes,mbNo],'')<>mrYes then Exit;
  if ListBox1.Items.Count<1 then
  begin
    MessageDlg('????????????','?????? ???????????????????? ?????? ???????????????????????????? (???????????? ????????)',mtError,[mbOk],'');
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
  s:=InputBox('?????????????? ?????????? ???????????????? ??????:', r.SeekStr,'');
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
     MessageDlg('????????????','???? ???????? ???????????? ???????????? ?? MS Word ('+FN+')',mtError,[mbOk],'');
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
     for c:=0 to 8 do  // 9 ?? 10 - ???? ?????????????????????????
     begin
       // ???????? ???????? "???????????????????? ???????????? ????????????????" ???? ????????????????????, ???????????????????? 2 ?? 5
       if not WA.ActiveDocument.PageSetup.DifferentFirstPageHeaderFooter and
          ((c = wdSeekFirstPageFooter) or (c = wdSeekFirstPageHeader)) then continue;
       // ???????? ???????? "?????????????????? ?????????????????????? ???????????? ?? ???????????????? ??????????????" ???? ????????????????????, ???????????????????? 3 ?? 6
       if not WA.Activedocument.PageSetup.OddAndEvenPagesHeaderFooter and
          ((c = wdSeekEvenPagesHeader) or (c = wdSeekEvenPagesFooter)) then continue;
       //
       docycle:=True;
       try
         WA.ActiveWindow.View.SeekView := c;
         //WA.ActiveWindow.ActivePane.View.SeekView := c;
       except
         // ???????????? ??????????, ?????????? ???????????? ?????? ?? ??????????????????
         continue;
       end;
       while docycle do
       begin
         WA.Selection.Find.ClearFormatting;
         WA.Selection.Find.Text :=  '\{\<*\>\}';       //'\{\<Block([0-9]@)\>\}';
         WA.Selection.Find.MatchWildcards := True; // ?????????????????? ?????????? * ? ?????? ??????????????????????
         WA.Selection.Find.Forward := True;
         WA.Selection.Find.Wrap := wdFindStop; // ?????????????????????????????? ?? ?????????? ??????????????????(???? ???????????????? ??????????????)
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
    showmessage('???????????????????????? ?????????????????? ??????????????????');
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
      MessageDlg('????????????','???? ???????? ???????????? ???????????? ?? MS Word ('+FN+')',mtError,[mbOk],'');
      Abort;
    end;
    WA.Visible := True; //False;
    cc := 3;     // ???????????????????? ???????????????????? ??????????????????:
                  // (1) - ???????? ??????????.; (2) - ?????????????? ????????????????????; (3)- ???????????? ????????????????????;
    WA.Caption := 'AutoFill: fill data to Word document';
    WA.ScreenUpdating := True; //False;
    WA.Documents.Open(FN);
    WA.ActiveWindow.View.&Type := 3 { wdPageView };
    for c:=0 to 8 do  // 9 ?? 10 - ???? ?????????????????????????
    begin
      // ???????? ???????? "???????????????????? ???????????? ????????????????" ???? ????????????????????, ???????????????????? 2 ?? 5
      if not WA.ActiveDocument.PageSetup.DifferentFirstPageHeaderFooter and
         ((c = wdSeekFirstPageFooter) or (c = wdSeekFirstPageHeader)) then continue;
      // ???????? ???????? "?????????????????? ?????????????????????? ???????????? ?? ???????????????? ??????????????" ???? ????????????????????, ???????????????????? 3 ?? 6
      if not WA.Activedocument.PageSetup.OddAndEvenPagesHeaderFooter and
         ((c = wdSeekEvenPagesHeader) or (c = wdSeekEvenPagesFooter)) then continue;
      //
      docycle:=True;
      try
        WA.ActiveWindow.View.SeekView := c;
        //WA.ActiveWindow.ActivePane.View.SeekView := c;
      except
        // ???????????? ??????????, ?????????? ???????????? ?????? ?? ??????????????????
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
      raise Exception.Create('???? ???????? ?????????????????? ???????????????? '+FN+#13#10+'?????????????????? ???? ?????????? ????????????????');
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
     MessageDlg('????????????','???? ???????? ???????????? ???????????? ?? MS Word ('+FN+')',mtError,[mbOk],'');
     Exit;
  end;
  ListBox1.Clear;
  try
     WA.Visible := False;
     // ???????????????????? ???????????????????? ??????????????????:
     // (1) - ???????? ??????????.; (2) - ?????????????? ????????????????????; (3)- ???????????? ????????????????????;
     if CheckBox1.Checked then cc := 3
     else cc := 1;
     WA.Caption := 'AutoFill: fill data to Word document';
     WA.ScreenUpdating := False;
     WA.Documents.Open(FN);
     WA.ActiveWindow.View.&Type := 3 { wdPageView };
     // ???????? ?????????????????????? ???????????? ???????????????? ???????????????????? ???? ??????????????????, ???? ???? ?????? ?????????????? ????????????:
     // (1) - ???????? ??????????.; (2) - ?????????????? ???????????????????? 1 ??????.; (3)- ???????????? ???????????????????? 1 ??????.;
     // (4) - ?????????????? ???????????????????? ???? 2-?? ??????.; (5) - ???????????? ???????????????????? ???? 2-?? ??????.
     if WA.ActiveDocument.PageSetup.DifferentFirstPageHeaderFooter then Inc(cc,2);
     for c:=1 to cc do
     begin
       case c of
         1: WA.ActiveWindow.ActivePane.View.SeekView := wdSeekMainDocument;
         2: WA.ActiveWindow.ActivePane.View.SeekView := wdSeekCurrentPageHeader;
         3: WA.ActiveWindow.ActivePane.View.SeekView := wdSeekCurrentPageFooter;
         4: begin
              try   // ???????? ?? ?????????????????? ?????????????????????? ???? ??????????????????????, ???? ?????????????????? ????????????
                WA.ActiveWindow.ActivePane.View.SeekView := wdSeekCurrentPageHeader;
                WA.ActiveWindow.ActivePane.View.NextHeaderFooter;
              except
                continue;   // ?????? ???????????????????????? - ?? ???? ???????? ...
              end;
            end;
         5: begin
              try   // ????. ???????? ( = 4)
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
         // ?????????????? ?????????? ?????????????? ?????????? ????????????:
 //        WA.Selection.Find.Replacement.Font.Hidden := False;
         WA.Selection.Find.Text := '\{\<*\>\}';
         WA.Selection.Find.MatchWildcards := True; // ?????????????????? ?????????? * ? ?????? ??????????????????????
//         WA.Selection.Find.Replacement.Text := 'WWWWWWWWWWWWWWWWWWWWWW';
         WA.Selection.Find.Forward := True;
         WA.Selection.Find.Wrap := wdFindStop; // ?????????????????????????????? ?? ?????????? ??????????????????(???? ???????????????? ??????????????)
         // ???????? ???????? ?????????????? ?????????? (??.??. ???? ??????????????):
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
          // ?????????????? ?????????? ?????????????? ?????????? ????????????:
          WA.Selection.Find.Replacement.Font.Hidden := False;
          WA.Selection.Find.Text := '{<'+DS.Fields[i].FieldName+'>}';
          WA.Selection.Find.Replacement.Text := DS.Fields[i].AsString;
          WA.Selection.Find.Forward := True;
          WA.Selection.Find.Wrap := 1 { wdFindContinue };
          // ???????? ???????? ?????????????? ?????????? (??.??. ???? ??????????????):
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
    showmessage('???????????????????????? ?????????????????? ??????????????????');
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
     MessageDlg('????????????','???? ???????? ???????????? ???????????? ?? MS Word ('+FN+')',mtError,[mbOk],'');
     Abort;
  end;
  ListBox1.Clear;
  try
     WA.Visible := False;
     cc := 3;     // ???????????????????? ???????????????????? ??????????????????:
                  // (1) - ???????? ??????????.; (2) - ?????????????? ????????????????????; (3)- ???????????? ????????????????????;
     WA.Caption := 'AutoFill: fill data to Word document';
     WA.ScreenUpdating := False;
     WA.Documents.Open(FN);
     WA.ActiveWindow.View.&Type := 3 { wdPageView };
     // ???????? ?????????????????????? ???????????? ???????????????? ???????????????????? ???? ??????????????????, ???? ???? ?????? ?????????????? ????????????:
     // (1) - ???????? ??????????.; (2) - ?????????????? ???????????????????? 1 ??????.; (3)- ???????????? ???????????????????? 1 ??????.;
     // (4) - ?????????????? ???????????????????? ???? 2-?? ??????.; (5) - ???????????? ???????????????????? ???? 2-?? ??????.
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
              try   // ???????? ?? ?????????????????? ?????????????????????? ???? ??????????????????????, ???? ?????????????????? ????????????
                WA.ActiveWindow.ActivePane.View.SeekView := Integer(wdSeekCurrentPageHeader);
                WA.ActiveWindow.ActivePane.View.NextHeaderFooter;
              except
                continue;   // ?????? ???????????????????????? - ?? ???? ???????? ...
              end;
            end;
         5: begin
              try   // ????. ???????? ( = 4)
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
         // ?????????????? ?????????? ?????????????? ?????????? ????????????:
 //        WA.Selection.Find.Replacement.Font.Hidden := False;
         WA.Selection.Find.Text := '\{\<*\>\}';
//         WA.Selection.Find.Replacement.Text := 'WWWWWWWWWWWWWWWWWWWWWW';
         WA.Selection.Find.Forward := True;
         WA.Selection.Find.Wrap := wdFindStop;
         // ???????? ???????? ?????????????? ?????????? (??.??. ???? ??????????????):
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
          // ?????????????? ?????????? ?????????????? ?????????? ????????????:
          WA.Selection.Find.Replacement.Font.Hidden := False;
          WA.Selection.Find.Text := '{<'+DS.Fields[i].FieldName+'>}';
          WA.Selection.Find.Replacement.Text := DS.Fields[i].AsString;
          WA.Selection.Find.Forward := True;
          WA.Selection.Find.Wrap := 1 { wdFindContinue };
          // ???????? ???????? ?????????????? ?????????? (??.??. ???? ??????????????):
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
        raise Exception.Create('???? ???????? ?????????????????? ???????????????? '+FN+#13#10+'?????????????????? ???? ?????????? ????????????????');
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
  Application.ScreenUpdating = False '???????????????????? ???????????????????? ????????????
  ActiveDocument.PrintPreview '?????????????????????????????? ????????????????
  ActiveDocument.ClosePrintPreview '?????????????? ?????????????????????????????? ????????????????
  Application.ScreenUpdating = True '???????????????? ??????????
End Sub
}
{
' WORD (WO) ?????????????? ?????????? (p) ?? ???????????? ?????? ???? (t)
' Dim WO As Object = CreateObject("Excel.Application")
' StoryRanges - ?????????????????? ???????????? ?????????????????? (??????.??????, ??????????????????????, ????????????, ???????????????????? ?? ??.??.)

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
???????????? ActiveDocument.PageSetup:
???????????????? OddAndEvenPagesHeaderFooter ????????????????????, ?????????????????????? ???? ?????????????????????? ???????????? ?? ???????????????? ??????????????:
=True (-1::Longint) - ????, ??????????????????????
=False (0::Longint) - ??????
DifferentFirstPageHeaderFooter - ???????????????????? ???? ???????????????????? ???????????? ????????????????
=True (-1::Longint) - ????
=False (0::Longint) - ??????
}

end.


}
//--------------------

end.

