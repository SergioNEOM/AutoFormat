program test1;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils, Variants, ComObj, CustApp
  { you can add units after this };


const
  ServerName = 'Word.Application';
var
   Server     : Variant;
   w:widestring;


type

  { TMyApplication }

  TMyApplication = class(TCustomApplication)
  protected
    procedure DoRun; override;
  public
  end;

{ TMyApplication }

procedure TMyApplication.DoRun;
var
  ErrorMsg: String;
begin
  { add your program here }
  if Assigned(InitProc) then
    TProcedure(InitProc);

  try
    Server := CreateOleObject(ServerName);
  except
    WriteLn('Unable to start Word.');
    Exit;
  end;

   {Open existing document}  //Substitute your path and doc
  w:= UTF8Decode('e:\mydoc.doc');
  Server.Documents.Open(w); //OLE uses BSTR (http://msdn.microsoft.com/en-us/library/windows/desktop/ms221069(v=vs.85).aspx). Only widestring is compatible with BSTR in FPC, so conversion is needed for nonlatin chars.
  Server.Visible := True;  {Make Word visible}


  // stop program loop
  Terminate;
end;

var
   Application: TMyApplication;
begin
  Application:=TMyApplication.Create(nil);
  Application.Title:='My Application';
  Application.Run;
  Application.Free;
end.



