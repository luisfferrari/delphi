program LerPacket;

uses
  Forms,
  Leitor01 in 'Leitor01.pas' {MainForm};

{$R *.RES}

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
