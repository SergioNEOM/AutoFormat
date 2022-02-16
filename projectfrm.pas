unit ProjectFrm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Buttons, ComCtrls, DBCtrls, EditBtn;

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
    procedure FormCreate(Sender: TObject);
    procedure SpeedButton1Click(Sender: TObject);
  private

  public
    //constructor Create(TheOwner: TComponent; Proj_id : integer = -1);
    function AddProject : integer;
  end;

var
  ProjectForm: TProjectForm;

implementation

{$R *.lfm}

uses LCLType, MainForm, DM, CommonUnit;

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
var
  t : TList;
  i : Integer;
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
    try
      t := DM1.GetTemplatesOfProject(MainForm1.CurrentProject.id);
      // ComboBox заполнить списком шаблонов в проекте:
      ComboBox1.Clear;
      for i:=0 to t.Capacity-1 do
      begin
        if (t.Items[i] is TTemplate) then
          ComboBox1.Items.AddObject(TTemplate(t.Items[i]).name,TTemplate(t.Items[i]));
      end;
      // установить у ComboBox свойство OnChange  или OnSelect для смены списка блоков после смены шаблона
      // пока планируется получать список блоков "на лету":
      // по id шаблона получаем в DataSet список блоков и заполняем ListBox (как вложенные объекты)
      // если не пойдёт, то запасной вариант:
      // задейстровать 2 запроса(master-detail), либо запрос из двух таблиц сканировать пока не меняется номер шаблона
      //...
    finally
      t.Free;
    end;
    ComboBox1.ItemIndex:=0;
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
  showmessage(inttostr(t));
end;

function TProjectForm.AddProject: integer;
begin
  // insert into projects new rec
  // MainForm1.CurrentUser.project := new.id;
  Result := -1;

end;

end.

