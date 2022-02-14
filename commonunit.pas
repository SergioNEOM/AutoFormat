unit CommonUnit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

resourcestring
  AppHeader = 'Auto Format';

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
    order  : integer;
    name   : string;
    info   : string;
    public
      procedure Clear;
      procedure SetBlockData(const bid:integer=-1;const bord:integer=0; const bname:string=''; const binfo:string='');
  end;

  {TPrjRec}

  TPrjRec = class(TObject)
    id     : integer;
    prjdate: TDate;
    prjinfo: string;
    tmp    : boolean;      // integer if file size ?
    public
      procedure Clear;
      procedure SetPrj(pid:integer=-1;pdate:TDate=0;pinfo:string='';ptmp:boolean=False);
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

procedure TPrjRec.SetPrj(pid:integer=-1;pdate:TDate=0;pinfo:string='';ptmp:boolean=False);
begin
  id := pid;
  prjdate := pdate;
  prjinfo := pinfo;
  tmp := ptmp;
end;

//--------------------

//--------------------

end.

