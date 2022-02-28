unit Blockfrm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Buttons, ComCtrls, DBCtrls, EditBtn, DBGrids, contnrs {for TObjectList};

type

  { TBlocksForm }

  TBlocksForm = class(TForm)
    Button3: TButton;
    CentralPanel: TPanel;
    DBGrid1: TDBGrid;
    DBText1: TDBText;
    DBText2: TDBText;
    Label1: TLabel;
    Label2: TLabel;
    OkButton: TBitBtn;
    CancelButton: TBitBtn;
    BottomPanel: TPanel;
    StaticText1: TStaticText;
    TopPanel: TPanel;
    procedure Button3Click(Sender: TObject);
    procedure CancelButtonClick(Sender: TObject);
    procedure ComboBox1Select(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure OkButtonClick(Sender: TObject);
    procedure SpeedButton1Click(Sender: TObject);
    procedure SpeedButton2Click(Sender: TObject);
  private

  public
    blklist,
    tmplist   :   TObjectList;
    BlocksWasChanged,
    TempsWasChanged           : Boolean;
    LastTempIdx : integer;
    //constructor Create(TheOwner: TComponent; Proj_id : integer = -1);
    function AddProject : integer;
    function FillTemplates : boolean;
    function FillBlocks : boolean;
  end;

var
  BlocksForm: TBlocksForm;

implementation

{$R *.lfm}

uses LCLType, md5,  MainForm, DM, CommonUnit, InputMemoFrm, Processing;

{ TBlocksForm }

{constructor TBlocksForm.Create(TheOwner: TComponent; Proj_id : integer = -1);
begin
  inherited Create(TheOwner);
  if Proj_id<=0 then         // no project ??? - error
  begin
    Application.MessageBox('Error adding project','ERROR', MB_ICONERROR+MB_OK);
    Close;
  end;
end;
}

procedure TBlocksForm.FormCreate(Sender: TObject);
begin
  BlocksWasChanged := False;
  TempsWasChanged  := False;
  LastTempIdx:=-1;
  if DM1.GetCurrentProjectId <=0 then
  begin
    // no current project ?
    // make sure:  will be no mistakes
    TopPanel.Enabled:=False;
    CentralPanel.Enabled:=False;
    OkButton.Enabled:=False;
  end
  else
  begin
    // Описание проекта
    // получить шаблоны
    //FillTemplates;
    //FillBlocks;
  end;
end;


procedure TBlocksForm.OkButtonClick(Sender: TObject);
begin
  {
  //if MessageDlg('Подтверждение записи в БД','Информация о проекте будет записана в БД'#13#10'Уверены?',mtConfirmation, mbYesNo,0)=mrYes then
  //begin;
    // Save Blocks if changed
    if DM1.SaveBlocks2DB(blklist, TTemplate(ComboBox1.Items.Objects[LastTempIdx]).id) then BlocksWasChanged:=False
    else
      begin
        MessageDlg('Ошибка записи в БД','Произошла ошибка при записи информации в БД',mtError, [mbOK],'');
        Exit;
      end;
    //TODO: Update Templates if changed

  // if all right, ModalResult := mrOk
  }
  ModalResult:=mrOK;
end;

procedure TBlocksForm.ComboBox1Select(Sender: TObject);
var
  c : TModalResult;
begin
  {
  if LastTempIdx = ComboBox1.ItemIndex then Exit; // ничего нового не выбрано
  // new template selected, but old data not saved!!
  while BlocksWasChanged do
  begin
    c := MessageDlg('Подтверждение','Информация предыдущего шаблона была изменена!'+
           #13#10'Сохранить изменения(Да), забыть их(Нет) или не менять шаблон(Отмена)?',
           mtConfirmation,mbYesNoCancel,'');
    case c of
      mrYes: if DM1.SaveBlocks2DB(blklist, TTemplate(ComboBox1.Items.Objects[LastTempIdx]).id) then BlocksWasChanged:=False;
      mrNo:  BlocksWasChanged:=False;
      mrCancel: Exit;
    end;
  end;
  // for new template:
  FillBlocks;
  }
end;

procedure TBlocksForm.Button3Click(Sender: TObject);
begin
  // изменить информацию в блоке
  with TInputMemoForm.Create(self) do
  try
    //TODO: Memo1.Lines.Text:=TBlock(blklist[ListBox1.ItemIndex]).name;
    if ShowModal=mrOK then
    begin
      StaticText1.Caption := Memo1.Text;
      //TODO: TBlock(blklist[ListBox1.ItemIndex]).name := Memo1.Text;
      //
      BlocksWasChanged := True;
    end;
  finally
    Free
  end;
end;

procedure TBlocksForm.CancelButtonClick(Sender: TObject);
begin
  if BlocksWasChanged or TempsWasChanged then
    if MessageDlg('Подтверждение отмены','Изменения проекта не записаны в БД!'#13#10'Вы точно хотите отказаться от сохранения?',mtConfirmation,mbYesNo,'')<> mrYes then Exit;
  ModalResult:=mrCancel;
end;

procedure TBlocksForm.SpeedButton1Click(Sender: TObject);
var
  t,i,r : integer;
  o : TStringList;
  b : TBlock;
  tmp: TTemplate;
begin
  //  кнопка добавления шаблона в проект
  //
  {
  if not OpenDialog1.Execute then Exit;
  tmp := TTemplate.Create;
  tmp.Clear;
  //TODO: надо ли заполнять uid:
  tmp.uid:= MD5Print(MD5File(OpenDialog1.FileName));
  tmp.name := InputBox('Ввод данных','Введите название шаблона (мах 32 знака)','');
  t := DM1.InsertTemplate(DM1.GetCurrentProjectId, tmp.name, OpenDialog1.FileName);
  // scan blocks...
  o := TaskForm.WordScanFile(OpenDialog1.FileName);
  if not Assigned(o) or (o.Count<1) then
  begin
    MessageDlg('Ошибка','Не удалось получить информацию из шаблона',mtError,[mbOK],'');
    Exit;
  end;
  //
  for i:=0 to o.Count-1 do
  begin
    b := TBlock.Create;
    b.SetBlockData(-1,0,o[i]);
    // пишем в БД
    r := DM1.AddBlock2DB(b, TTemplate(tmplist[ComboBox1.ItemIndex]).id );
    if r>0 then b.id := r;
    //TODO: else - ??? В файле блок есть, а в БД не записалось!!!
  end;
  // добавить шаблон в ComboBox и сделать текущим (перечитать блоки из БД)
  ComboBox1.AddItem(tmp.name,tmp);
  //
  TempsWasChanged:=True;
  }
end;

procedure TBlocksForm.SpeedButton2Click(Sender: TObject);
begin
  // delete template from project ... ????
  //
  // if MessageDlg()=mrYes then begin delete...   TempsWasChanged:=True; end;
end;

function TBlocksForm.AddProject: integer;
begin
  // insert into projects new rec
  // MainForm1.CurrentUser.project := new.id;
  Result := -1;
end;


function TBlocksForm.FillTemplates: boolean;
var
  i : Integer;
begin
  Result := False;
  {
  // Получить шаблоны из БД
  tmplist := DM1.GetTemplatesOfProject(MainForm1.CurrentProject.id);
  if tmplist.Count>0 then
  begin
    for i:=0 to tmplist.Count-1 do
    begin
      if Assigned(tmplist[i]) then
        ComboBox1.Items.Add(TTemplate(tmplist[i]).name);
    end;
    Result := True;
  end;
  }
end;


function TBlocksForm.FillBlocks: boolean;
var
  i : Integer;
begin
  {
  // пока планируется получать список блоков "на лету":
  // по id шаблона получаем в DataSet список блоков и заполняем ListBox (как вложенные объекты)
  // если не пойдёт, то запасной вариант:
  // задейстровать 2 запроса(master-detail), либо запрос из двух таблиц сканировать пока не меняется номер шаблона
  //...
  Result := False;
  //
  if ComboBox1.ItemIndex<0 then Exit;
  // Получить блоки из БД по идентификатору шаблона
  if not Assigned(tmplist[ComboBox1.ItemIndex]) then
  begin
    showmessage('not assigned');
    Exit;
  end;
  blklist := DM1.GetBlocksFromTmp( TTemplate(tmplist[ComboBox1.ItemIndex]).id );
  if not Assigned(blklist) then
  begin
    //showmessage('not assigned blklist');
    Exit;
  end;
  // ComboBox заполнить списком шаблонов в проекте:
  ListBox1.Clear;
  if blklist.Count>0 then
  begin
    for i:=0 to blklist.Count-1 do
    begin
      if Assigned(blklist[i]) then
        ListBox1.Items.Add(TBlock(blklist[i]).name)
      {else
        showmessage('blklist['+inttostr(i)+'] not assigned!')}  ;
    end;
    Result := True;
  end;
  }
end;


end.
