program Gateway;

uses
  Forms,
  Gateway_01 in 'Gateway_01.pas' {TcpSrvForm},
  FuncColetor in '..\Funcoes\FuncColetor.pas',
  thread_gravacao_acp245 in 'thread_gravacao_acp245.pas',
  thread_resultado in 'thread_resultado.pas',
  thread_msgwebtech in 'thread_msgwebtech.pas',
  thread_gravacao_webtech in 'thread_gravacao_webtech.pas',
  FunAcp in '..\Funcoes\FunAcp.pas',
  thread_gravacao_satlight in 'thread_gravacao_satlight.pas',
  thread_MsgAcp245 in 'thread_MsgAcp245.pas',
  thread_query in 'thread_query.pas',
  thread_msgquanta in 'thread_msgquanta.pas',
  thread_gravacao_Quanta in 'thread_gravacao_Quanta.pas',
  FunQuanta in '..\Funcoes\FunQuanta.pas',
  thread_msgsatlight in 'thread_msgsatlight.pas',
  thread_gravacao_quanta_acp in 'thread_gravacao_quanta_acp.pas',
  thread_MsgQuanta_Acp in 'thread_MsgQuanta_Acp.pas',
  thread_gravacao_QUECLINK in 'thread_gravacao_QUECLINK.pas',
  thread_MsgET06 in 'thread_MsgET06.pas',
  thread_gravacao_CalAmp in 'thread_gravacao_CalAmp.pas',
  thread_MsgCalAmp in 'thread_MsgCalAmp.pas',
  FunCalAmp in '..\Funcoes\FunCalAmp.pas',
  FunQUECLINK in '..\Funcoes\FunQUECLINK.pas',
  FunET06 in '..\Funcoes\FunET06.pas';

{$R *.RES}

begin
   Application.Title := 'Multi Gateway SatCompany';
   Application.CreateForm(TTcpSrvForm, TcpSrvForm);
  Application.Run;

end.
