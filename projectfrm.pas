unit ProjectFrm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Buttons, ComCtrls, DBCtrls, EditBtn, contnrs {for TObjectList};

type

  { TProjectForm }

  TProjectForm = class(TForm)
    Button3: TButton;
    CentralPanel: TPanel;
    ComboBox1: TComboBox;
    ListBox1: TListBox;
    OkButton: TBitBtn;
    CancelButton: TBitBtn;
    BottomPanel: TPanel;
    OpenDialog1: TOpenDialog;
    PrjInfoLabel: TLabel;
    SpeedButton1: TSpeedButton;
    SpeedButton2: TSpeedButton;
    StaticText1: TStaticText;
    TopPanel: TPanel;
    procedure Button3Click(Sender: TObject);
    procedure ComboBox1Select(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure ListBox1SelectionChange(Sender: TObject; User: boolean);
    procedure SpeedButton1Click(Sender: TObject);
  private

  public
    blklist,
    tmplist   :   TObjectList;
    //constructor Create(TheOwner: TComponent; Proj_id : integer = -1);
    function AddProject : integer;
    function FillTemplates : boolean;
    function FillBlocks : boolean;
  end;

var
  ProjectForm: TProjectForm;

implementation

{$R *.lfm}

uses LCLType, MainForm, DM, CommonUnit, InputMemoFrm;

{ TProjectForm }

{constructor TProjectForm.Create(TheOwner: TComponent; Proj_id : integer = -1);
begin
  inherited Create(TheOwner);
  if Proj_id<=0 then         // no project ??? - error
  begin
    Application.MessageBox('Error adding project','ERROR', MB_ICONERROR+MB_OK);
    Close;
  end;
end;
}

procedure TProjectForm.FormCreate(Sender: TObject);
begin
  if MainForm1.CurrentProject.id <=0 then
  begin
    // no current project ?
    // make sure:  will be no mistakes
    PrjInfoLabel.Caption:='Ошибка!!!'#13#10' Нет текущего проекта!';
    TopPanel.Enabled:=False;
    CentralPanel.Enabled:=False;
    OkButton.Enabled:=False;
  end
  else
  begin
    // Описание проекта
    PrjInfoLabel.Caption:=MainForm1.CurrentProject.prjinfo;
    // получить шаблоны
    FillTemplates;
    // для смены списка блоков после смены шаблона
    if ComboBox1.Items.Count>0 then ComboBox1.ItemIndex:=0;
    // у ComboBox свойство OnSelect  := FillBlocks (tmp_id)
    FillBlocks;
    if ListBox1.Items.Count>0 then ListBox1.ItemIndex:=0;
  end;
end;

procedure TProjectForm.ListBox1SelectionChange(Sender: TObject; User: boolean);
begin
  if not Assigned(blklist) or
     (ListBox1.ItemIndex<0)  or
     not Assigned(blklist[ListBox1.ItemIndex]) then Exit;;
  StaticText1.Caption:=TBlock(blklist[ListBox1.ItemIndex]).name;
end;

procedure TProjectForm.ComboBox1Select(Sender: TObject);
begin
  FillBlocks;
end;

procedure TProjectForm.Button3Click(Sender: TObject);
begin
  with TInputMemoForm.Create(self) do
  try
    Memo1.Lines.Text:=TBlock(blklist[ListBox1.ItemIndex]).name;
    if ShowModal=mrOK then
    begin
      StaticText1.Caption := Memo1.Text
      TBock(blklist[ListBox1.ItemIndex]).name := Memo1.Text;
    end;
  finally
    Free
  end;
end;

procedure TProjectForm.SpeedButton1Click(Sender: TObject);
var
  t : integer;
begin
  if not OpenDialog1.Execute then Exit;
  t := DM1.InsertTemplate(
        MainForm1.CurrentProject.id,
        InputBox('Ввод данных','Введите описание шаблона',''),
        OpenDialog1.FileName);
  showmessage('speedbutton1Click->'+inttostr(t));
end;

function TProjectForm.AddProject: integer;
begin
  // insert into projects new rec
  // MainForm1.CurrentUser.project := new.id;
  Result := -1;
end;


function TProjectForm.FillTemplates: boolean;
var
  i : Integer;
begin
  Result := False;
  // Получить шаблоны из БД
  tmplist := DM1.GetTemplatesOfProject(MainForm1.CurrentProject.id);
  // ComboBox заполнить списком шаблонов в проекте:
  ComboBox1.Clear;
  if tmplist.Count>0 then
  begin
    for i:=0 to tmplist.Count-1 do
    begin
      if Assigned(tmplist[i]) then
        ComboBox1.Items.Add(TTemplate(tmplist[i]).name);
    end;
    Result := True;
  end;
end;


function TProjectForm.FillBlocks: boolean;
var
  i : Integer;
begin
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
end;



end.

