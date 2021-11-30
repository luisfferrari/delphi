{*_* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

Author:       François Piette
Creation:     Aug 29, 1999
Version:      7.01
Description:  Basic TCP server showing how to use TWSocketServer and
              TWSocketClient components and how to send binary data
              which requires OverbyteIcsBinCliDemo as client application.
EMail:        francois.piette@overbyte.be  http://www.overbyte.be
Support:      Use the mailing list twsocket@elists.org
              Follow "support" link at http://www.overbyte.be for subscription.
Legal issues: Copyright (C) 1999-2010 by François PIETTE
              Rue de Grady 24, 4053 Embourg, Belgium. Fax: +32-4-365.74.56
              <francois.piette@overbyte.be>

              This software is provided 'as-is', without any express or
              implied warranty.  In no event will the author be held liable
              for any  damages arising from the use of this software.

              Permission is granted to anyone to use this software for any
              purpose, including commercial applications, and to alter it
              and redistribute it freely, subject to the following
              restrictions:

              1. The origin of this software must not be misrepresented,
                 you must not claim that you wrote the original software.
                 If you use this software in a product, an acknowledgment
                 in the product documentation would be appreciated but is
                 not required.

              2. Altered source versions must be plainly marked as such, and
                 must not be misrepresented as being the original software.

              3. This notice may not be removed or altered from any source
                 distribution.

              4. You must register this software by sending a picture postcard
                 to the author. Use a nice stamp and mention your name, street
                 address, EMail address and any comment you like to say.
History:
Sep 05, 1999 V1.01 Adapted for Delphi 1
Oct 15, 2000 V1.02 Display remote and local socket binding when a client
                   connect.
Nov 11, 2000 V1.03 Implemented OnLineLimitExceeded event
Dec 15, 2001 V1.03 In command help changed #10#13 to the correct value #13#10.
Jul 19, 2008 V6.00 F.Piette made some changes for Unicode
Nov 28, 2008 V7.01 A.Garrels added command binary, requires OverbyteIcsBinCliDemo.
Dec 20, 2008 V7.02 F.Piette removed an implicit string conversion warning in
                   WMAppStartup (Hostname).

 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
unit Gateway_01;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  StdCtrls, IniFiles, Buttons, Grids, DateUtils, ExtCtrls,
  DB, DBClient, DBGrids, Contnrs, Types, Variants,
  OverbyteIcsWSocket, OverbyteIcsWSocketS, OverbyteIcsWndControl,
  FuncColetor, FunAcp, WinSock,
  thread_gravacao_acp, thread_gravacao_webtech, thread_gravacao_satlight,
  thread_resultado, thread_msgwebtech, thread_MsgAcp245, thread_query;

const
  TcpSrvVersion = 702;
  CopyRight     = ' TcpSrv (c) 1999-2010 by François PIETTE. V7.02';
//  WM_APPSTARTUP = WM_USER + 1;

type

  { TTcpSrvClient is the class which will be instanciated by server component }
  { for each new client. N simultaneous clients means N TTcpSrvClient will be }
  { instanciated. Each being used to handle only a single client.             }
  { We can add any data that has to be private for each client, such as       }
  { receive buffer or any other data needed for processing.                   }

  TTcpSrvClient = class(TWSocketClient)
  Public
    RcvdPacket   : String;
    Id           : String;
    NumRecebido  : Integer;
    NumMens      : Integer;
    ConnectTime  : TDateTime;
    UltMensagem  : TDateTime;
    Protocolo    : String;
    FirmWare     : String;
    MsgSequencia : Integer;
  end;


  TTcpSrvForm = class(TForm)
    TimerGravacao: TTimer;
    DataSource1: TDataSource;
    DBGrid1: TDBGrid;
    Panel1: TPanel;
    lbl_mensagem: TLabel;
    pacotes: TLabel;
    ConexoesCount: TLabel;
    Label2: TLabel;
    Label1: TLabel;
    SpeedButton1: TSpeedButton;
    tStoped: TSpeedButton;
    tRunning: TSpeedButton;
    tResultado: TSpeedButton;
    tGravacao: TSpeedButton;
    Tmensagem: TSpeedButton;
    TimerOutros: TTimer;
    PacotesSeg: TLabel;

    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure WSocketServer1ClientConnect(Sender: TObject;
      Client: TWSocketClient; Error: Word);
    procedure WSocketServer1ClientDisconnect(Sender: TObject;
      Client: TWSocketClient; Error: Word);
    procedure WSocketServer1BgException(Sender: TObject; E: Exception;
      var CanClose: Boolean);

    procedure leconfig;
    procedure TimerGravacaoTimer(Sender: TObject);
    procedure SpeedButton1Click(Sender: TObject);
    Procedure StartThreadGravacao;
    Procedure StartThreadMensagem;
    Procedure StartThreadResultado;
    Procedure StartThreadQuery;
    Procedure StopThreads;
    Procedure StopTcpServer;
    procedure SpeedButton2Click(Sender: TObject);
    procedure TimerOutrosTimer(Sender: TObject);
    Procedure GravarPacote(pPacket: String);

  private
    Threadgravacao_acp : Array of gravacao_acp;
    Threadgravacao_satlight : Array of gravacao_satlight;
    Threadgravacao_webtech : Array of gravacao_webtech;
    ThreadMsgWebTech : MsgWebTech;
    ThreadMsgAcp245 : MsgAcp245;
    Threadresultado : resultado;
    ThreadQuery : dbquery;

    NumpackRec: Integer;
    DirInbox   : String;
    DirProcess : String;
    DirErros   : String;
    DirSql     : String;
    Arq_Log    : String;
    Arq_Sql    : String;
    db_hostname,
    db_username,
    db_password,
    db_database,
    cpr_db_hostname,
    cpr_db_username,
    cpr_db_password,
    cpr_db_database,
    Srv_Equipo,
    Srv_Proto,
    Srv_Port,
    Srv_Addr,
    cmd_pos_login: String;
    Altura,Topo,Esquerda: Integer;
    Debug: Shortint;
    Num_Threads,
    Num_Clientes,
    db_inserts,
    ErroLogin,
    Timer_Arquivo: Integer;
    WSocketServer1: TWSocketServer;
    WSocketUdpRec: TWSocket;
    WSocketUdpEnv: TWSocket;
    PacketRec:  Array [0..1500] of Byte;
    ServerStartUp: TDateTime;
    Arq_ThreadId: Word;
    Encerrado: boolean;

    procedure StartTcpUdpServer;
    procedure WSocketUdpRecDataAvailable(Sender: TObject; Error: Word);
    procedure WSocketUdpRecSessionConnected(Sender: TObject; Error: Word);
    procedure WSocketUdpRecSessionClosed(Sender: TObject; Error: Word);
    procedure WSocketUdpRecBgException(Sender: TObject; E: Exception;
      var CanClose: Boolean);

    procedure ClientDataAvailable_SATLIGHT_TCP(Sender: TObject; Error: Word);
    procedure ClientDataAvailable_ACP(Sender: TObject; Error: Word);
    procedure ClientDataAvailable_WEBTECH(Sender: TObject; Error: Word);
    procedure ClientBgException(Sender       : TObject;
                                E            : Exception;
                                var CanClose : Boolean);
    procedure ClientLineLimitExceeded(Sender        : TObject;
                                      Cnt           : LongInt;
                                      var ClearData : Boolean);

    Public
    Recebidos:  tClientDataSet;
    Conexoes:   tClientDataSet;
    AcpNews:    tClientDataSet;

    //Variaveis para a thread atualizar o ultimo ciclo
    Thgravacao_acp_ultimo      : tDateTime;
    Thgravacao_webtech_ultimo  : tDateTime;
    Thgravacao_satlight_ultimo : tDateTime;
    ThMsgWebTech_ultimo        : tDateTime;
    ThMsgAcp245_ultimo         : tDateTime;
    Thresultado_ultimo         : tDateTime;
    Thdb_query_Ultimo          : tDateTime;


    procedure RecebeResultado(pId: String;  pClient: Integer;  pIP,pPorta: String; pResposta: TStream);
    procedure AckNackSatligh(pIP,pPorta: String; pResposta: TByteDynArray);
    Function EnviaMsgWebTech(var Mensagens: TClientDataset) : Boolean;
    Function EnviaMsgAcp245(var Mensagens: TClientDataset) : Boolean;
    //    property IniFileName : String read FIniFileName write FIniFileName;

  end;

var
  TcpSrvForm: TTcpSrvForm;

implementation

{$R *.DFM}

const
    SectionWindow      = 'WindowTcpSrv';


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TTcpSrvForm.FormCreate(Sender: TObject);
begin

{$IFDEF DELPHI10_UP}
    // BDS2006 has built-in memory leak detection and display
    ReportMemoryLeaksOnShutdown := (DebugHook <> 0);
{$ENDIF}
Arq_ThreadId := 0;
NumpackRec   := 0;
ErroLogin    := 0;

leconfig;

Thgravacao_acp_ultimo := Now;
Thgravacao_satlight_ultimo := Now;
Thgravacao_webtech_ultimo := Now;
ThMsgWebTech_ultimo := Now;
ThMsgAcp245_ultimo := Now;
Thresultado_ultimo := Now;


SetLength(Threadgravacao_acp, Num_Threads);
SetLength(Threadgravacao_satlight, Num_Threads);
SetLength(Threadgravacao_webtech, Num_Threads);

Num_Threads  := Num_Threads -1;

//Definicao do Arquivo de gravacao dos dados recebidos
recebidos := tClientDataSet.Create(Application);

if Srv_Equipo = 'ACP' Then
Begin
   recebidos.FieldDefs.Add('Tcp_Client', ftInteger, 0, False);
   recebidos.FieldDefs.Add('IP', ftString, 15, False);
   recebidos.FieldDefs.Add('Porta', ftInteger, 0, False);
   recebidos.FieldDefs.Add('ID', ftString, 20, False);
   recebidos.FieldDefs.Add('MsgSequencia', ftInteger, 0, False);
   recebidos.FieldDefs.Add('Datagrama', ftBlob, 0, False);
   recebidos.FieldDefs.Add('Processado', ftBoolean, 0, False);

   //Controle de Pacotes ACP Recebido
   AcpNews := tClientDataSet.Create(Application);
   AcpNews.FieldDefs.Add('Type', ftInteger, 0, False);
   AcpNews.FieldDefs.Add('Size', ftInteger, 0, False);
   AcpNews.FieldDefs.Add('PackeStr', ftString, 1500, False);
   AcpNews.CreateDataSet;

   TcpSrvForm.Caption := 'Multi Gateway ACP - ' +   srv_proto + ' : ' +  srv_port


End
Else if Srv_Equipo = 'WEBTECH' Then
Begin
   recebidos.FieldDefs.Add('Tcp_Client', ftInteger, 0, False);
   recebidos.FieldDefs.Add('IP', ftString, 15, False);
   recebidos.FieldDefs.Add('Porta', ftInteger, 0, False);
   recebidos.FieldDefs.Add('ID', ftString, 20, False);
   recebidos.FieldDefs.Add('MsgSequencia', ftInteger, 0, False);
   recebidos.FieldDefs.Add('Datagrama', ftString, 1540, False);
   recebidos.FieldDefs.Add('Processado', FtBoolean, 0, False);
   TcpSrvForm.Caption := 'Multi Gateway WEBTECH - ' +   srv_proto + ' : ' +  srv_port
End
Else if Srv_Equipo = 'SATLIGHT' Then
Begin
   recebidos.FieldDefs.Add('Tcp_Client', ftInteger, 0, False);
   recebidos.FieldDefs.Add('IP', ftString, 15, False);
   recebidos.FieldDefs.Add('Porta', ftInteger, 0, False);
   recebidos.FieldDefs.Add('ID', ftString, 20, False);
   recebidos.FieldDefs.Add('MsgSequencia', ftInteger, 0, False);
   recebidos.FieldDefs.Add('Datagrama', ftBlob, 0, False);
   recebidos.FieldDefs.Add('Processado', ftBoolean, 0, False);
   TcpSrvForm.Caption := 'Multi Gateway SATLIGHT - ' +   srv_proto + ' : ' +  srv_port;
End;

recebidos.CreateDataSet;

TcpSrvForm.Width  := 478;
TcpSrvForm.Height := Altura;
TcpSrvForm.Top    := Topo;
TcpSrvForm.Left   := Esquerda;

Encerrado         := False;

end;

{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TTcpSrvForm.StartTcpUdpServer;

begin
   if srv_proto = 'tcp' then
   Begin
      WSocketServer1                    := TWSocketServer.Create(TcpSrvForm);
      WSocketServer1.OnBgException      := WSocketServer1BgException;
      WSocketServer1.OnClientConnect    := WSocketServer1ClientConnect;
      WSocketServer1.OnClientDisconnect := WSocketServer1ClientDisconnect;
      WSocketServer1.MaxClients         := Num_Clientes;
      WSocketServer1.Banner             := '';
      WSocketServer1.Proto              := srv_proto;         { Use TCP protocol  }
      WSocketServer1.Port               := srv_port;          { Use telnet port   }
      WSocketServer1.Addr               := srv_addr;          { Use any interface }
      WSocketServer1.ClientClass        := TTcpSrvClient;     { Use our component }
      WSocketServer1.Listen;                           { Start litening    }
      SalvaLog(Arq_Log,'TcpServer Inicializado:  ');
   End
   //UDP
   Else
   Begin

      try
         WSocketUdpRec                        := TWSocketServer.Create(TcpSrvForm);
         WSocketUdpRec.OnSessionConnected     := WSocketUdpRecSessionConnected;
         WSocketUdpRec.OnSessionClosed        := WSocketUdpRecSessionClosed;
         WSocketUdpRec.OnDataAvailable        := WSocketUdpRecDataAvailable;
         WSocketUdpRec.OnBgException          := WSocketUdpRecBgException;
         WSocketUdpRec.Proto                  := srv_proto;         { Use TCP/UDP protocol  }
         WSocketUdpRec.Port                   := srv_port;          { Use srv_port   }
         WSocketUdpRec.Addr                   := srv_addr;          { Use any interface }
         WSocketUdpRec.listen;
         WSocketUdpEnv                        := TWSocketServer.Create(TcpSrvForm);
         WSocketUdpEnv.Proto                  := srv_proto;         { Use TCP/UDP protocol  }
         WSocketUdpEnv.Addr                   := srv_addr;          { Use any interface }

      except
         WSocketUdpRec.Free;
         WSocketUdpRec := nil;
         WSocketUdpEnv.Free;
         WSocketUdpEnv := nil;
      end;
   End;

end;
{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TTcpSrvForm.StopTcpServer;
begin


   if srv_proto = 'tcp' then
      Try
         If Assigned(WSocketServer1) Then
            WSocketServer1.Release;
      Except
         If Assigned(WSocketServer1) Then
            WSocketServer1.Free;
      End
   Else
      Try
         If Assigned(WSocketUdpRec) Then
            WSocketUdpRec.Release;
         If Assigned(WSocketUdpEnv) Then
            WSocketUdpRec.Release;
      Except
         If Assigned(WSocketUdpRec) Then
            WSocketUdpRec.Free;
         If Assigned(WSocketUdpEnv) Then
            WSocketUdpRec.Free;
      End;

   Sleep(1000);
   Try

      if srv_proto = 'tcp' then
            If Assigned(WSocketServer1) Then
               FreeandNil(WSocketServer1)
      Else
      Begin
         If Assigned(WSocketUdpEnv) Then
            FreeandNil(WSocketUdpRec);
         If Assigned(WSocketUdpRec) Then
            FreeandNil(WSocketUdpRec);
      End;

   Except
   End;

   SalvaLog(Arq_Log,'Serviços UDP/TCP Encerrados:');


end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
Procedure TTcpSrvForm.StartThreadGravacao;
Var Contador: Word;
begin

//Inicializa a thread de gravacao no banco de dados
if Srv_Equipo = 'ACP' then
Begin
   for Contador := 0 to Num_Threads do
   Begin

      if Assigned(Threadgravacao_acp[Contador]) then
         Threadgravacao_acp[Contador].Free;

      Threadgravacao_acp[Contador] := gravacao_acp.Create(true);
      Threadgravacao_acp[Contador].db_hostname       := db_hostname;
      Threadgravacao_acp[Contador].db_username       := db_username;
      Threadgravacao_acp[Contador].db_password       := db_password;
      Threadgravacao_acp[Contador].db_database       := db_database;
      Threadgravacao_acp[Contador].db_inserts        := db_inserts;
      Threadgravacao_acp[Contador].Debug             := Debug;
      Threadgravacao_acp[Contador].Arq_Log           := Arq_Log;
      Threadgravacao_acp[Contador].DirInbox          := DirInbox;
      Threadgravacao_acp[Contador].DirProcess        := DirProcess;
      Threadgravacao_acp[Contador].DirErros          := DirErros;
      Threadgravacao_acp[Contador].DirSql            := DirSql;
      Threadgravacao_acp[Contador].PortaLocal        := StrToint(Srv_Port);
      Threadgravacao_acp[Contador].ServerStartUp     := ServerStartUp;
      Threadgravacao_acp[Contador].ThreadId          := Contador;
      Threadgravacao_acp[Contador].Encerrar          := False;
      Threadgravacao_acp[Contador].FreeOnTerminate   := True;     // Destroi a thread quando terminar de executar
      Threadgravacao_acp[Contador].Priority          := tpnormal; // Prioridade Normal
      Threadgravacao_acp[Contador].Resume;                        // Executa a thread

   End;
End
Else if Srv_Equipo = 'SATLIGHT' then
Begin

   for Contador := 0 to Num_Threads do
   Begin

      If Assigned(Threadgravacao_satlight[contador]) Then
         Threadgravacao_satlight[contador].Free;

      Threadgravacao_satlight[contador] := gravacao_satlight.Create(true);
      Threadgravacao_satlight[contador].db_hostname       := db_hostname;
      Threadgravacao_satlight[contador].db_username       := db_username;
      Threadgravacao_satlight[contador].db_password       := db_password;
      Threadgravacao_satlight[contador].db_database       := db_database;
      Threadgravacao_satlight[contador].db_inserts        := db_inserts;
      Threadgravacao_satlight[contador].Debug             := Debug;
      Threadgravacao_satlight[contador].Arq_Log           := Arq_Log;
      Threadgravacao_satlight[contador].DirInbox          := DirInbox;
      Threadgravacao_satlight[contador].DirProcess        := DirProcess;
      Threadgravacao_satlight[contador].DirErros          := DirErros;
      Threadgravacao_satlight[contador].DirSql            := DirSql;
      Threadgravacao_satlight[contador].Encerrar          := False;
      Threadgravacao_satlight[Contador].ThreadId          := Contador;
      Threadgravacao_satlight[contador].FreeOnTerminate   := True; // Destroi a thread quando terminar de executar
      Threadgravacao_satlight[contador].Priority          := tpnormal; // Prioridade Normal
      Threadgravacao_satlight[contador].Resume;           // Executa a thread

   End;
End
Else if Srv_Equipo = 'WEBTECH' then
Begin

   for Contador := 0 to Num_Threads do
   Begin

      If Assigned(Threadgravacao_webtech[contador]) Then
         Threadgravacao_webtech[contador].Free;

      Threadgravacao_webtech[contador] := gravacao_webtech.Create(True);
      Threadgravacao_webtech[contador].db_hostname       := db_hostname;
      Threadgravacao_webtech[contador].db_username       := db_username;
      Threadgravacao_webtech[contador].db_password       := db_password;
      Threadgravacao_webtech[contador].db_database       := db_database;
      Threadgravacao_webtech[contador].db_inserts        := db_inserts;
      Threadgravacao_webtech[contador].PortaLocal        := StrToint(Srv_Port);
      Threadgravacao_webtech[contador].Debug             := Debug;
      Threadgravacao_webtech[contador].Arq_Log           := Arq_Log;
      Threadgravacao_webtech[contador].DirInbox          := DirInbox;
      Threadgravacao_webtech[contador].DirProcess        := DirProcess;
      Threadgravacao_webtech[contador].DirErros          := DirErros;
      Threadgravacao_webtech[contador].DirSql            := DirSql;
      Threadgravacao_webtech[contador].Encerrar          := False;
      Threadgravacao_webtech[Contador].ThreadId          := Contador;
      Threadgravacao_webtech[contador].FreeOnTerminate   := True; // Destroi a thread quando terminar de executar
      Threadgravacao_webtech[contador].Priority          := tpnormal; // Prioridade Normal
      Threadgravacao_webtech[contador].Resume;           // Executa a thread
   End;
End;
End;

{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
Procedure TTcpSrvForm.StartThreadMensagem;
Begin
if Srv_Equipo = 'ACP' then
Begin
   if Assigned(ThreadMsgAcp245) then
      ThreadMsgAcp245.Terminate;

   //Inicializa a thread de envio de mensagens
   ThreadMsgAcp245                   := msgAcp245.Create(true);
   ThreadMsgAcp245.db_hostname       := db_hostname;
   ThreadMsgAcp245.db_username       := db_username;
   ThreadMsgAcp245.db_password       := db_password;
   ThreadMsgAcp245.db_database       := db_database;
   ThreadMsgAcp245.cpr_db_hostname   := cpr_db_hostname;
   ThreadMsgAcp245.cpr_db_username   := cpr_db_username;
   ThreadMsgAcp245.cpr_db_password   := cpr_db_password;
   ThreadMsgAcp245.cpr_db_database   := cpr_db_database;
   ThreadMsgAcp245.Srv_Equipo        := Srv_Equipo;
   ThreadMsgAcp245.Arq_Log           := Arq_Log;
   ThreadMsgAcp245.Encerrar          := False;
   ThreadMsgAcp245.FreeOnTerminate   := True; // Destroi a thread quando terminar de executar
   ThreadMsgAcp245.Priority          := tpnormal; // Prioridade Normal
   ThreadMsgAcp245.PortaLocal        := Srv_Port;
   ThreadMsgAcp245.Debug             := Debug;
   ThreadMsgAcp245.Resume; // Executa a thread

end
Else if Srv_Equipo = 'WEBTECH' then
Begin

   if Assigned(ThreadMsgWebTech) then
      ThreadMsgWebTech.Terminate;

   //Inicializa a thread de envio de mensagens
   ThreadMsgWebTech                   := msgWebTech.Create(true);
   ThreadMsgWebTech.db_hostname       := db_hostname;
   ThreadMsgWebTech.db_username       := db_username;
   ThreadMsgWebTech.db_password       := db_password;
   ThreadMsgWebTech.db_database       := db_database;
   ThreadMsgWebTech.Srv_Equipo        := Srv_Equipo;
   ThreadMsgWebTech.Arq_Log           := Arq_Log;
   ThreadMsgWebTech.Encerrar          := False;
   ThreadMsgWebTech.FreeOnTerminate   := True; // Destroi a thread quando terminar de executar
   ThreadMsgWebTech.Priority          := tpnormal; // Prioridade Normal
   ThreadMsgWebTech.PortaLocal        := Srv_Port;
   ThreadMsgWebTech.Debug             := Debug;
   ThreadMsgWebTech.Resume; // Executa a thread

End;

End;

{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
Procedure TTcpSrvForm.StartThreadResultado;
Begin

   if Assigned(Threadresultado) then
      Threadresultado.Free;
   //Inicializa a thread de resultados da Gravacao ACP
   Threadresultado                   := resultado.Create(true);
   Threadresultado.Arq_Log           := Arq_Log;
   Threadresultado.DirProcess        := DirProcess;
   Threadresultado.Encerrar          := False;
   Threadresultado.FreeOnTerminate   := True; // Destroi a thread quando terminar de executar
   Threadresultado.Priority          := tpnormal; // Prioridade Normal
   Threadresultado.Resume;           // Executa a thread

End;

{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
Procedure TTcpSrvForm.StartThreadQuery;
Begin

   if Assigned(ThreadQuery) then
      FreeAndNil(ThreadQuery);
   //Inicializa a thread de resultados da Gravacao ACP
   ThreadQuery                       := dbquery.Create(true);
   ThreadQuery.db_hostname           := db_hostname;
   ThreadQuery.db_username           := db_username;
   ThreadQuery.db_password           := db_password;
   ThreadQuery.db_database           := db_database;
   ThreadQuery.Arq_Log               := Arq_Log;
   ThreadQuery.DirSql                := DirSql;
   ThreadQuery.Encerrar              := False;
   ThreadQuery.Debug                 := Debug;
   ThreadQuery.FreeOnTerminate       := True; // Destroi a thread quando terminar de executar
   ThreadQuery.Priority              := tpnormal; // Prioridade Normal
   ThreadQuery.Resume;           // Executa a thread

End;

{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
Procedure TTcpSrvForm.StopThreads;
Var Contador: Word;
begin
Try
   If Assigned(ThreadQuery) Then
      ThreadQuery.Encerrar := True;

   //Encerra a thread de gravacao no banco de dados
   if Srv_Equipo = 'ACP' then
   Begin

      for Contador  := 0 to Num_Threads do
         Threadgravacao_acp[Contador].Encerrar := True;

   End
   Else if Srv_Equipo = 'SATLIGHT' then
   Begin

      for Contador  := 0 to Num_Threads do
         Threadgravacao_satlight[Contador].Encerrar := True;

      If Assigned(Threadresultado) Then
         Threadresultado.Encerrar := True;

   End
   Else if Srv_Equipo = 'WEBTECH' then
   Begin
      for Contador  := 0 to Num_Threads do
         Threadgravacao_webtech[Contador].Encerrar := True;
   End;

   if Srv_Equipo = 'ACP' then
   Begin
      If Assigned(ThreadMsgAcp245) Then
         ThreadMsgAcp245.Encerrar := True;
   End
   Else if Srv_Equipo = 'WEBTECH' then
   Begin
      If Assigned(ThreadMsgWebTech) Then
         ThreadMsgWebTech.Encerrar := True;
   End;

   Sleep(2000);

Except

End;
End;

{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TTcpSrvForm.FormShow(Sender: TObject);
begin

   StartTcpUdpServer;

   StartThreadGravacao;
   StartThreadMensagem;
   StartThreadQuery;

   if (Srv_Equipo = 'ACP') or (Srv_Equipo = 'SATLIGHT') Then
      StartThreadResultado;

   Sleep(10);

   TimerGravacao.Interval   := Timer_Arquivo*1000;
   TimerGravacao.Enabled    := True;
   TimerOutros.Enabled      := True;
   TimerOutrosTimer(Self);
   ServerStartUp            := now;

end;



{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TTcpSrvForm.FormClose(Sender: TObject; var Action: TCloseAction);
Begin

if Encerrado Then
   Application.Free;

Encerrado := true;

Try

   TimerGravacao.Enabled    := False;
   TimerOutros.Enabled      := False;

   if Srv_Equipo = 'ACP' Then
   Begin
      if AcpNews.RecordCount > 0  then
         AcpNews.SaveToFile(ExtractFileDir(Application.ExeName) + '\acpnews.245');
   End;

   lbl_mensagem.Color   := ClRed;
   lbl_mensagem.Caption := 'Aguarde... Encerrando Serviços';

   Try
      StopTcpServer;
   Except
      If Srv_Proto = 'tcp' Then
         If Assigned(WSocketServer1) Then
            WSocketServer1.Free;
      Begin
         If Assigned(WSocketUdpRec) Then
            WSocketUdpRec.Free;
         If Assigned(WSocketUdpEnv) Then
            WSocketUdpEnv.Free;
      End;

   End;

   Try
      StopThreadS;
   Except
   End;

   SalvaLog(Arq_Log,'Threads Encerradas');

   TimerGravacaoTimer(Sender);

   if Srv_Equipo = 'ACP' Then
   Begin
      if AcpNews.RecordCount > 0  then
         AcpNews.SaveToFile(ExtractFileDir(Application.ExeName) + '\acpnews.245');
   End;

   If Assigned(recebidos) Then
      recebidos.Free;
   if Assigned(AcpNews) Then
      AcpNews.Free;
   if Assigned(Conexoes) then
      Conexoes.Free;

   SalvaLog(Arq_Log,'Serviço Encerrado com sucesso! ');

Except
   Application.Destroy;
End;

end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TTcpSrvForm.WSocketUdpRecSessionConnected(Sender: TObject; Error: Word);
begin
   if Srv_Equipo = 'SATLIGHT' then
   Begin
   End;
end;

{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TTcpSrvForm.WSocketServer1ClientConnect(
    Sender : TObject;
    Client : TWSocketClient;
    Error  : Word);
begin
   if Srv_Equipo = 'ACP' then
   Begin
      with Client as TTcpSrvClient do
      begin
         LineMode             := False;
         LineEdit             := False;
         MultiThreaded        := False;
         LineLimit            := 1500; { Do not accept long lines }
         OnDataAvailable      := ClientDataAvailable_ACP;
         OnLineLimitExceeded  := ClientLineLimitExceeded;
         OnBgException        := ClientBgException;
         ConnectTime          := Now;
         Id                   := '';
         ConexoesCount.Caption := InttoStr(TWSocketServer(Sender).ClientCount);
      end;
   End
   Else if Srv_Equipo = 'WEBTECH' then
   Begin
      with Client as TTcpSrvClient do
      begin
         LineMode            := False;
         LineEdit            := False;
         LineLimit           := 1500; { Do not accept long lines }
         MultiThreaded        := False;
         OnDataAvailable     := ClientDataAvailable_WEBTECH;
         OnLineLimitExceeded := ClientLineLimitExceeded;
         OnBgException       := ClientBgException;
         ConnectTime         := Now;
         Id                  := '';
         ConexoesCount.Caption := InttoStr(TWSocketServer(Sender).ClientCount);
      end;
   End
   Else if Srv_Equipo = 'SATLIGHT' then
   Begin
      with Client as TTcpSrvClient do
      begin
         LineMode            := False;
         LineEdit            := False;
         LineLimit           := 1500; { Do not accept long lines }
         MultiThreaded        := False;
         OnDataAvailable     := ClientDataAvailable_SATLIGHT_TCP;
         OnLineLimitExceeded := ClientLineLimitExceeded;
         OnBgException       := ClientBgException;
         ConnectTime         := Now;
         Id                  := '';
         ConexoesCount.Caption := InttoStr(TWSocketServer(Sender).ClientCount);
      end;
   End;
end;

{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TTcpSrvForm.WSocketServer1ClientDisconnect(
   Sender : TObject;
   Client : TWSocketClient;
   Error  : Word);
begin
   with Client as TTcpSrvClient do
   begin

      if Debug in [1,5,9] then
         SalvaLog(Arq_Log,'Cliente desconectou: ' + PeerAddr + ':' + PeerPort +
                          ' - Duração: ' + FormatDateTime('hh:nn:ss',Now - ConnectTime) +
                          ' TCP_Client_Id: ' + InttoStr(Client.CliId));

      ConexoesCount.Caption    := InttoStr( TWSocketServer(Sender).ClientCount -1);

   end;
end;

{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TTcpSrvForm.WSocketUdpRecSessionClosed(Sender : TObject; Error  : Word);
begin

//      ConexoesCount.Caption    := InttoStr( TWSocketServer(Sender).ClientCount -1);

end;

{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TTcpSrvForm.ClientLineLimitExceeded(
   Sender        : TObject;
   Cnt           : LongInt;
   var ClearData : Boolean);
begin
   with Sender as TTcpSrvClient do
   begin
      SalvaLog(Arq_Log,'Tamanho de linha excedido:  ' + GetPeerAddr + '. Closing.');
      ClearData := TRUE;
      Close;
   end;
end;

{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
Function TTcpSrvForm.EnviaMsgWebTech(var Mensagens: TClientDataset) : Boolean;
Var Contador  : Integer;
    Client    : TTcpSrvClient;
    Comando   : String;
Begin

Result := False;

For Contador := WSocketServer1.ClientCount - 1 DownTo 0 do
Begin

   Client := WSocketServer1.Client[Contador] as TTcpSrvClient;

   With Client as TTcpSrvClient do
   Begin

      If Mensagens.Locate('ID', Id,[]) then
      Begin
         Try

            Comando := Mensagens.FieldByName('Mensagem').AsString;
            SendStr(Comando+ Char(13)+ Char(10));
            Mensagens.Edit;
            Mensagens.FieldByName('Status').AsInteger := 3;
            Mensagens.Post;
            NumMens      := NumMens + 1;
            MsgSequencia := Mensagens.FieldByName('Sequencia').AsInteger;
            Result       := True;

            If Debug in [4,5,9] Then
               SalvaLog(Arq_Log,'Mensagem Enviada: (ID/Sequencia): (' + Mensagens.FieldByName('ID').AsString + ':' + Mensagens.FieldByName('Sequencia').AsString + ')');

         Except
            Close;
         End;

      End;
   End;

End;
End;

{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
Function TTcpSrvForm.EnviaMsgAcp245(var Mensagens: TClientDataset) : Boolean;
Var Contador  : Integer;
    Contador2 : Integer;
    Client    : TTcpSrvClient;
//    Comando   : String;
    BlobF     : TBlobField;
    Stream    : TMemoryStream;
    PacketCom : TByteDynArray;
    PacketStr : String;

Begin

Result := True;

For Contador := WSocketServer1.ClientCount - 1 DownTo 0 do
Begin

   Client := WSocketServer1.Client[Contador] as TTcpSrvClient;

   With Client as TTcpSrvClient do
   Begin

      If Mensagens.Locate('ID', Id,[]) then
      Begin
         Try
            If Debug in [4,5,9] Then
               SalvaLog(Arq_Log,'Conectado: (ID/Sequencia): (' + Mensagens.FieldByName('ID').AsString + ':' + Mensagens.FieldByName('Sequencia').AsString + ')');

            Stream    := TMemoryStream.Create;
            BlobF     := Mensagens.FieldByName('Comando') as TBlobField;
            try
               blobF.SaveToStream(Stream);
               StreamToByteArray(Stream,PacketCom);
               Stream.Free;
            Except
               Stream.Free;
            end;

            Send(PacketCom,Length(PacketCom));
            Mensagens.Edit;
            Mensagens.FieldByName('Status').AsInteger := 3;
            Mensagens.Post;
            NumMens      := NumMens + 1;
            MsgSequencia := Mensagens.FieldByName('Sequencia').AsInteger;
            Result       := True;

            PacketStr := '';
            for Contador2 := 0 to Length(PacketCom) - 1 do
               PacketStr := PacketStr + IntToStr(PacketCom[Contador2]) + ':';
            If Debug in [4,5,9] Then
               SalvaLog(Arq_Log,'Mensagem Enviada: (ID/Sequencia): (' + Mensagens.FieldByName('ID').AsString + ':' + Mensagens.FieldByName('Sequencia').AsString + ') ' + PacketStr);

         Except
            If Debug in [4,5,9] Then
               SalvaLog(Arq_Log,'Erro ao Enviar Mensagem: (ID/Sequencia): (' + Mensagens.FieldByName('ID').AsString + ':' + Mensagens.FieldByName('Sequencia').AsString + ')');
            Result := False;
            Close;
         End;

      End;
   End;

End;
End;

{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TTcpSrvForm.RecebeResultado(pId: String; pClient: Integer; pIP,pPorta: String; pResposta: TStream);
Var Contador   : Integer;
    Contador2  : Word;
    Client     : TTcpSrvClient;
    Msg        : String;
    PacketRes  : TByteDynArray;
Begin

if Srv_Equipo = 'ACP' then
Begin

   pResposta.Position := 0;

   StreamToByteArray(pResposta,PacketRes);

   if Length(PacketRes) > 0 then
   Begin
      Msg := '';
      for Contador2 := 0 to Length(PacketRes) - 1 do
         Msg := Msg + InttoStr(PacketRes[Contador2]) + ':' ;
   End;

   For Contador := 0 to WSocketServer1.ClientCount - 1 do
   Begin

      Client := WSocketServer1.Client[Contador] as TTcpSrvClient;

      With Client as TTcpSrvClient do
      Begin
         if (CliId = pClient) and (id = '') then
            Id := pId;

         if (CliId = pClient) and (Length(PacketRes) > 0)  then
         Begin

            If Debug in [4,5,9] Then
               SalvaLog(Arq_Log,'Ack Enviado: (ID): (' + ID + '): ' + Msg  );

            Send(PacketRes,Length(PacketRes));
            Client.Flush;
            Exit;

         End

      End;

   End;
End
Else if (Srv_Equipo = 'SATLIGHT') and (Srv_Proto = 'udp') then
Begin

   pResposta.Position := 0;

   StreamToByteArray(pResposta,PacketRes);

   if Length(PacketRes) > 0 then
   Begin
      Msg := '';
      for Contador2 := 0 to Length(PacketRes) - 1 do
         Msg := Msg + InttoStr(PacketRes[Contador2]) + ':' ;
   End;

   Begin
      WSocketUdpEnv.Proto      := 'udp';
      WSocketUdpEnv.Addr       := pIP;     { That's a broadcast  ! }
      WSocketUdpEnv.Port       := pPorta;
      WSocketUdpEnv.LocalPort  := srv_port;
      { UDP is connectionless. Connect will just open the socket }
      WSocketUdpEnv.Connect;
      WSocketUdpEnv. Send(PacketRes,Length(PacketRes));
      WSocketUdpEnv.Close;
   End;

End;

End;

{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TTcpSrvForm.AckNackSatligh(pIP,pPorta: String; pResposta: TByteDynArray);
Begin

   Begin
      WSocketUdpEnv.Proto      := 'udp';
      WSocketUdpEnv.Addr       := pIP;     { That's a broadcast  ! }
      WSocketUdpEnv.Port       := pPorta;
      WSocketUdpEnv.LocalPort  := '10001';
      { UDP is connectionless. Connect will just open the socket }
      WSocketUdpEnv.Connect;
      WSocketUdpEnv. Send(pResposta,Length(pResposta));
      WSocketUdpEnv.Close;
   End;

End;

{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TTcpSrvForm.ClientDataAvailable_ACP(
    Sender : TObject;
    Error  : Word);
Var BytesTot  : Integer;
    blobF     : TBlobField;
    BufferRec : TStream;
    Contador  : Word;
//    PacketEnv : tBytes;
//Const PacketRes  : Array [0..41] of Byte = (6,2,33,29,4,64,135,1,8,3,128,0,0,1,3,13,128,32,138,137,85,2,128,0,1,84,116,148,80,10,3,32,13,4,64,135,1,8,80,16,1,0);
//Const PacketRes  : Array [0..79] of Byte = (2,8,33,38,4,64,135,1,8,0,194,0,13,128,32,138,137,85,2,128,0,1,84,116,148,80,0,10,0,17,2,0,30,0,65,2,14,16,6,2,33,29,4,64,135,1,8,3,128,0,0,1,3,13,128,32,138,137,85,2,128,0,1,84,116,148,80,10,3,32,13,4,64,135,1,8,80,16,1,0);

begin

   with Sender as TTcpSrvClient do
   begin

      if Error <> 0 then
      Begin
         SalvaLog(Arq_Log,'Erro: ' + IntToStr(Error) + WSocketErrorDesc(Error) +  ' - ' + GetPeerAddr + ':' + GetPeerPort);
         Exit;
      End;

      BytesTot  := Receive(@PacketRec, Sizeof(PacketRec));

      if BytesTot <= 0 then
         Exit;

      RcvdPacket := '';

      for Contador := 0 to BytesTot -1 do
         RcvdPacket := RcvdPacket + inttoStr(Ord(PacketRec[Contador])) + ':';

      GravarPacote(RcvdPacket);

      if Debug in [1,5,9]  then
         SalvaLog(Arq_Log,'Recebido: ' + RcvdPacket );

      while Recebidos.ReadOnly do
      Begin
         Sleep(1);
         SalvaLog(Arq_Log,'Aguardando Destravar Arquivo Recebido: ');
      End;

      Begin

         Recebidos.Append;
         Recebidos.FieldByName('IP').AsString             :=  GetPeerAddr;
         Recebidos.FieldByName('ID').AsString             :=  ID;
         Recebidos.FieldByName('Porta').AsString          :=  GetPeerPort;
         Recebidos.FieldByName('TCP_CLIENT').AsInteger    :=  CliId;
         Recebidos.FieldByName('Processado').AsBoolean    := False;
         Recebidos.FieldByName('MsgSequencia').AsInteger  := MsgSequencia;
         blobF := Recebidos.FieldByName('DataGrama') as TBlobField;

         Try
            BufferRec := Recebidos.CreateBlobStream(blobF, bmWrite) ;
            try
               BufferRec.Write(PacketRec,BytesTot) ;
            finally
               BufferRec.Free;
            end;
         Except
            SalvaLog(Arq_Log,'Erro ao Criar o TBlobField: ' );
         End;

         Recebidos.Post;

      End;

      Inc(NumPackRec);
      Pacotes.Caption    := InttoStr(NumpackRec);
      PacotesSeg.Caption := FormatFloat('##0', NumpackRec /((now-ServerStartUp) *24*60*60));
      //Atualiza pacotes recebidos / mensagens Enviadas deste cliente
      NumRecebido     := NumRecebido + 1;
      UltMensagem     := Now;


{
      SetLength(PacketEnv,80);
      for Contador := 0 to 79 do
      Begin
         PacketEnv[Contador] := Byte(PacketRes[Contador]);
      End;

      Send(PacketEnv,Length(PacketEnv));
 }

   end;

end;

{SATLIGHT}
{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TTcpSrvForm.ClientDataAvailable_SATLIGHT_TCP(
    Sender : TObject;
    Error  : Word);
Var Contador    : Integer;
    BytesTot    : Integer;
    blobF       : TBlobField;
    BufferRec   : TStream;
begin

   //TCP
   if Srv_Proto = 'tcp' then
      with Sender as TTcpSrvClient do
      begin

         if Error <> 0 then
         Begin
            SalvaLog(Arq_Log,'Erro: ' + IntToStr(Error) + WSocketErrorDesc(Error) +  ' - ' + GetPeerAddr + ':' + GetPeerPort);
            Exit;
         End;

         BytesTot  := Receive(@PacketRec, Sizeof(PacketRec));

         if BytesTot <= 0 then
            Exit;

         RcvdPacket := '';

         for Contador := 0 to BytesTot -1 do
            RcvdPacket := RcvdPacket + inttoStr(Ord(PacketRec[Contador])) + ':';

         if Debug in [1,5,9]  then
            SalvaLog(Arq_Log,'Recebido: ' + RcvdPacket );

         while Recebidos.ReadOnly do
         Begin
            Sleep(1);
            SalvaLog(Arq_Log,'Aguardando Destravar Arquivo Recebido: ');
         End;

         Begin

            Recebidos.Append;
            Recebidos.FieldByName('IP').AsString             :=  GetPeerAddr;
            Recebidos.FieldByName('ID').AsString             :=  ID;
            Recebidos.FieldByName('Porta').AsString          :=  GetPeerPort;
            Recebidos.FieldByName('TCP_CLIENT').AsInteger    :=  CliId;
            Recebidos.FieldByName('Processado').AsBoolean    := False;
            Recebidos.FieldByName('MsgSequencia').AsInteger  := MsgSequencia;
            blobF := Recebidos.FieldByName('DataGrama') as TBlobField;

            Try
               BufferRec := Recebidos.CreateBlobStream(blobF, bmWrite) ;
               try
                  BufferRec.Write(PacketRec,BytesTot) ;
               finally
                  BufferRec.Free;
               end;
            Except
               SalvaLog(Arq_Log,'Erro ao Criar o TBlobField: ' );
            End;

            Recebidos.Post;

         End;

         Inc(NumPackRec);
         Pacotes.Caption    := InttoStr(NumpackRec);
         PacotesSeg.Caption := FormatFloat('##0', NumpackRec /((now-ServerStartUp) *24*60*60));

         //Atualiza pacotes recebidos / mensagens Enviadas deste cliente
         NumRecebido     := NumRecebido + 1;
         UltMensagem     := Now;

      end;


end;
{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{SATLIGHT UDP}

procedure TTcpSrvForm.WSocketUdpRecDataAvailable(Sender: TObject; Error: Word);
var
    Buffer : array [0..1023] of Ansichar;
    Src: TSockAddrIn;
    SrcLen: integer;
    Resposta    : TByteDynArray;
    BytesTot    : Integer;
    Contador    : Integer;
    blobF       : TBlobField;
    BufferRec   : TStream;
    RcvdPacket  : String;
    ip,porta    : String;
Begin

   begin
      SrcLen := SizeOf(Src);
      BytesTot  := WSocketUdpRec.ReceiveFrom(@Buffer, SizeOf(Buffer), Src, SrcLen);
       Try
          ip    := inet_ntoa(Src.sin_addr);
          porta := inttoStr(Src.sin_port);
          SetLength(Resposta,2);
          Resposta[0] := Ord(Buffer[6]);
          Resposta[1] := 59;
//          If WSocketUdpRec.Sendto(Src, SrcLen, @Resposta, SizeOf(Resposta)) <> SOCKET_ERROR Then

//          If (WSocketUdpRec.State <> wsClosed) and (WSocketUdpRec.Send(@Resposta, SizeOf(Resposta)) <> SOCKET_ERROR) Then
//             SalvaLog(Arq_Log,'Socket Ativo - Ack Enviado - IP: ' + IP + ' Porta: '+ porta +  ' Qtd Pct: ' + InttoStr(Ord(Buffer[6])))
//          Else
          Begin
             If WSocketUdpRec.State = wsInvalidState Then
                SalvaLog(Arq_Log,'wsInvalidState' )
             Else If WSocketUdpRec.State = wsOpened Then
                SalvaLog(Arq_Log,'wsOpened' )
             Else If WSocketUdpRec.State = wsBound Then
                SalvaLog(Arq_Log,'wsBound' )
             Else If WSocketUdpRec.State = wsConnecting Then
                SalvaLog(Arq_Log,'wsConnecting' )
             Else If WSocketUdpRec.State = wsSocksConnected Then
                SalvaLog(Arq_Log,'wsSocksConnected' )
             Else If WSocketUdpRec.State = wsConnected Then
                SalvaLog(Arq_Log,'wsConnected' )
             Else If WSocketUdpRec.State = wsAccepting Then
                SalvaLog(Arq_Log,'wsAccepting')
             Else If WSocketUdpRec.State = wsListening Then
                SalvaLog(Arq_Log,'wsListening' )
             Else If WSocketUdpRec.State = wsClosed Then
                SalvaLog(Arq_Log,'wsClosed');

             AckNackSatligh(IP,Porta, Resposta);
             SalvaLog(Arq_Log,'Ack Enviado - IP: ' + IP + ' Porta: '+ porta +  ' Qtd Pct: ' + InttoStr(Ord(Buffer[6])));
          End;
       Except
          SalvaLog(Arq_Log,'Erro depois de receber o pacote');
       End;


       if BytesTot >= 0 then
       begin

          //WSocketUdpRec.SendStr(Char(1) + Char(2));

          // no udp é usado tambem como contador
          Inc(NumPackRec);
          Buffer[BytesTot] := #0;

          for Contador := 0 to BytesTot -1 do
              RcvdPacket := RcvdPacket + inttoStr(Ord(Buffer[Contador])) + ':';

          if Debug in [1,5,9]  then
          Begin
             SalvaLog(Arq_Log,'IP: ' + IP + ' -  Porta: '+ porta );
             SalvaLog(Arq_Log,'Recebido: ' + RcvdPacket);
          End;
            Begin

               Recebidos.Append;
               Recebidos.FieldByName('IP').AsString             := ip;
               Recebidos.FieldByName('Porta').AsString          := Porta;
               Recebidos.FieldByName('Processado').AsBoolean    := False;
               Recebidos.FieldByName('MsgSequencia').AsInteger  := NumpackRec;
               blobF := Recebidos.FieldByName('DataGrama') as TBlobField;

               Try
                  BufferRec := Recebidos.CreateBlobStream(blobF, bmWrite) ;
                  try
                     BufferRec.Write(PacketRec,BytesTot) ;
                  finally
                     BufferRec.Free;
                  end;
               Except
                  SalvaLog(Arq_Log,'Erro ao Criar o TBlobField: ' );
               End;

               Recebidos.Post;

            End;

            Pacotes.Caption    := InttoStr(NumpackRec);
            PacotesSeg.Caption := FormatFloat('##0', NumpackRec /((now-ServerStartUp) *24*60*60));

   {
                   DataAvailableLabel.Caption := IntToStr(atoi(DataAvailableLabel.caption) + 1) +
                                             '  ' + String(StrPas(inet_ntoa(Src.sin_addr))) +
                                             ':'  + IntToStr(ntohs(Src.sin_port)) +
                                             '--> ' + String(StrPas(Buffer));
   }

       end;
   end;
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{WEBTECH}

procedure TTcpSrvForm.ClientDataAvailable_WEBTECH(
    Sender : TObject;
    Error  : Word);
Var Contador    : Integer;
    BytesTot    : Integer;
    LinhaRec    : String;
    LinhaProc   : String;
    Separador   : String;
    BytesIni    : Integer;
    Login       : Boolean;
    TmpStr      : String;
    Size        : Word;

Begin

   Login := False;

   with Sender as TTcpSrvClient do
   begin

      if Error <> 0 then
      Begin
         SalvaLog(Arq_Log,'Erro: ' + IntToStr(Error) + WSocketErrorDesc(Error) +  ' - ' + GetPeerAddr + ':' + GetPeerPort);
         Exit;
      End;

      BytesTot  := Receive(@PacketRec, Sizeof(PacketRec));

      if BytesTot <= 0 then
         Exit;

      RcvdPacket := '';

      for Contador := 0 to BytesTot -1 do
         RcvdPacket := RcvdPacket + Chr(PacketRec[Contador]);

      if Debug in [1,5,9]  then
         SalvaLog(Arq_Log,'Recebido: ' + RcvdPacket +  ' - ' + GetPeerAddr + ':' + GetPeerPort)
      Else if (Copy(RcvdPacket,1,5) <> 'login') and
              (Copy(RcvdPacket,1,8) <> 'L0 L3,01') and
              (Copy(RcvdPacket,1,3) <> 'C0 ') then
      Begin

         TmpStr := '';
         for Contador := 0 to BytesTot - 1 do
            TmpStr := TmpStr + InttoStr(Ord(PacketRec[Contador])) + ':';
         SalvaLog(Arq_Log,'Pacote não Previsto <T> ? : ' + TmpStr );

      End;

      BytesIni := 1;

      while BytesIni < BytesTot do
      Begin

         LinhaRec := '';
         if ( Pos(Char(10),RcvdPacket) =0 ) and ( Pos(Char(13),RcvdPacket) =0 ) then
         Begin
            LinhaRec := RcvdPacket;
            BytesIni := BytesTot;
         End
         Else
         Begin
            BytesIni := Pos(Char(10),RcvdPacket);
            if BytesIni = 0  then
               BytesIni := Pos(Char(13),RcvdPacket);
            LinhaRec := Copy(RcvdPacket,1,BytesIni-1);
            Inc(BytesIni);
         End;

         //Se for Login So salva o ID do Equipamento
         if Pos('login ', LinhaRec) > 0 then
         Begin
            //Para identificar o protocolo, o <t> vem primeiro o Login
            //O <T> vem primeiro 2 octetos com o tamanho  disponivel no pacote
            if Copy(LinhaRec,1,5) = 'login' then
            Begin
               Protocolo := 't';  //login <id> <opt>\n
               LinhaRec  := Copy(LinhaRec, Pos('login ', LinhaRec) + 6, 1500);
            End
            Else
            Begin
               Protocolo := 'T'; //<length>login <id> <opt>
               SalvaLog(Arq_Log,'Pacote T recebido: ' + LinhaRec);
               Size      := (PacketRec[0] *256) + PacketRec[1];
               LinhaRec  := Copy(LinhaRec, Pos('login ', LinhaRec) + 6, Size);
            End;

            Separador := ' ';

            StringProcessar(LinhaRec,LinhaProc,Separador);
            if LinhaProc <> '' Then
               Id := Trim(LinhaProc);

            if LinhaProc <> '' Then
               FirmWare := Trim(LinhaRec);

            //Se o ID recebido for pelo menos um numero valido...
            if paraInteiro(id) > 0 then
            Begin

               Login := True;

               Recebidos.Append;
               Recebidos.FieldByName('TCP_CLIENT').AsInteger       := CliId;
               Recebidos.FieldByName('IP').AsString                := GetPeerAddr;
               Recebidos.FieldByName('Porta').AsString             := GetPeerPort;
               Recebidos.FieldByName('ID').AsString                := Id;
               Recebidos.FieldByName('MsgSequencia').AsInteger     := 0;
               Recebidos.FieldByName('DataGrama').AsString         := 'login';
               Recebidos.FieldByName('Processado').AsBoolean       := False;

               Recebidos.Post;

            End;

            BytesIni := Pos('L0 L3,01,',LinhaRec);
            if BytesIni > 0 then
            Begin
               LinhaRec := Copy(LinhaRec, BytesIni,1500) ;
               Continue
            End
            Else
               BytesIni := BytesTot;

         End

         //Senao Salva o Pacote para processar
         Else if id <> '' then
         Begin

            while Recebidos.ReadOnly do
            Begin
               Sleep(1);
               SalvaLog(Arq_Log,'Aguardando Destravar Arquivo Recebido: ');
            End;

            Inc(NumPackRec);

            if Protocolo = 'T' then
               LinhaRec := Copy(LinhaRec,3,1500);

            Recebidos.Append;
            Recebidos.FieldByName('TCP_CLIENT').AsInteger           := CliId;
            Recebidos.FieldByName('IP').AsString                    := GetPeerAddr;
            Recebidos.FieldByName('Porta').AsString                 := GetPeerPort;
            Recebidos.FieldByName('ID').AsString                    := Id;
            Recebidos.FieldByName('MsgSequencia').AsInteger         := MsgSequencia;
            Recebidos.FieldByName('DataGrama').AsString             := LinhaRec;
            Recebidos.FieldByName('Processado').AsBoolean           := False;
            Recebidos.Post;

            //Atualiza pacotes recebidos / mensagens Enviadas deste cliente
            NumRecebido     := NumRecebido + 1;
            UltMensagem     := Now;
            BytesIni        := BytesTot;

         End
         //Recebeu dados e não logou ainda ?
         Else if Copy(LinhaRec,1,5) = 'GET /' then
         Begin
            Inc(ErroLogin);
            if (ErroLogin Mod 100 = 0)  then
               SalvaLog(Arq_Log,'Desconectando... Recebeu dados repetidos: ' + InttoStr(ErroLogin) + ' Ocorrencias :' + LinhaRec + ' - IP:Porta' + GetPeerAddr + ':' + GetPeerPort);
            CloseDelayed;
         End
         Else if id = '' then
         Begin
            SalvaLog(Arq_Log,'Desconectando... Recebeu dados sem login:' + LinhaRec + ' - IP:Porta' + GetPeerAddr + ':' + GetPeerPort);
            CloseDelayed;
         End;

      End;


      //Envia ACK Se o Protocolo For = <T>
      if Protocolo = 'T' then
         Try
            SendStr(Char(0) + Char(0));
            if Debug in [1,5,9]  then
               SalvaLog(Arq_Log,'ACK Enviado: ' + GetPeerAddr + ':' + GetPeerPort );
         Except
            SalvaLog(Arq_Log,'Erro ao enviar ACK: ' + GetPeerAddr + ':' + GetPeerPort );
         End
      Else if login and (Cmd_Pos_login <> '') then
         Try
            Size := Length(Cmd_Pos_Login);
            if Protocolo = 't' then
               SendStr(Cmd_Pos_Login + Chr(13) + Chr(10))
            Else
               SendStr(Char(0) + Char(Size)  + Cmd_Pos_Login);

            if Debug in [1,5,9]  then
               SalvaLog(Arq_Log,'Enviado CMD_POS_LOGIN: ' + Cmd_Pos_Login );
         Except
            SalvaLog(Arq_Log,'Erro ao enviar CMD_POS_LOGIN: ' + Cmd_Pos_Login );
         End;

      Inc(NumPackRec);
      Pacotes.Caption    := InttoStr(NumpackRec);
      PacotesSeg.Caption := FormatFloat('##0', NumpackRec /((now-ServerStartUp) *24*60*60));

   end;

end;


{
antigo
procedure TTcpSrvForm.ClientDataAvailable_WEBTECH(
    Sender : TObject;
    Error  : Word);
Var Separador: String;
    LinhaRec:  String;
    LinhaProc: String;
    BytesTot:  Integer;
    BytesIni:  Integer;
    Contador:  integer;
    BufferRec: Array[0..1402] of AnsiChar;
    Separadores:  TSysCharSet;
    Login: Boolean;
    TmpStr: String;

Begin

   Login := False;

   with Sender as TTcpSrvClient do
   begin

      if Error <> 0 then
      Begin
         SalvaLog(Arq_Log,'Erro: ' + IntToStr(Error) + WSocketErrorDesc(Error) +  ' - ' + GetPeerAddr + ':' + GetPeerPort);
         Exit;
      End;

      Separadores := [#13,#10];

      BytesTot := Receive(@BufferRec, Sizeof(BufferRec)-1);

      if BytesTot <= 1 then
         Exit;

      BytesIni := 1;

      //Salva o Pacote recebido
      RcvdPacket := '';
      for Contador := 0 to BytesTot - 1 do
         RcvdPacket := RcvdPacket + Char(BufferRec[Contador]);

      if Debug in [1,5,9]  then
         SalvaLog(Arq_Log,'Recebido: ' + RcvdPacket +  ' - ' + GetPeerAddr + ':' + GetPeerPort);

      if (Copy(RcvdPacket,1,5) <> 'login') and (Copy(RcvdPacket,1,8) <> 'L0 L3,01') then
      Begin
         TmpStr := '';
         for Contador := 0 to BytesTot - 1 do
            TmpStr := TmpStr + InttoStr(Ord(BufferRec[Contador])) + ':';
         SalvaLog(Arq_Log,'Pacote não Previsto: ' + TmpStr );

      End;

      while BytesIni < BytesTot do
      Begin

         LinhaRec := '';
         For Contador := BytesIni to BytesTot  do
         if (Not CharInSet(RcvdPacket[Contador],Separadores)) then
            LinhaRec := LinhaRec + RcvdPacket[Contador]
         Else
         Begin
            BytesIni := Contador;
            Break;
         End;

         //Se for Login So salva o ID do Equipamento
         if Pos('login ', LinhaRec) > 0 then
         Begin
            //Para identificar o protocolo, o <t> vem primeiro o Login
            //O <T> vem primeiro 2 octetos com o tamanho  disponivel no pacote
            if Copy(LinhaRec,1,5) = 'login' then
            Begin
               Protocolo := 't';  //login <id> <opt>\n
               LinhaRec  := Copy(LinhaRec, Pos('login ', LinhaRec) + 6, 1500);
            End
            Else
            Begin
               Protocolo := 'T'; //<length>login <id> <opt>
               SalvaLog(Arq_Log,'Pacote T recebido: ' + LinhaRec);
               LinhaRec  := Copy(LinhaRec, Pos('login ', LinhaRec) + 6, 1500);
               BytesIni  := BytesTot;
            End;

            Separador := ' ';

            StringProcessar(LinhaRec,LinhaProc,Separador);
            if LinhaProc <> '' Then
               Id := Trim(LinhaProc);

            if LinhaProc <> '' Then
               FirmWare := Trim(LinhaRec);

            if Pos('L0 L3,01,',LinhaRec) > 0 then
               LinhaRec := Copy(LinhaRec, Pos('L0 L3,01,',LinhaRec),Length(LinhaRec)) + Chr(13) + Char(10);

            Login := True;

            Recebidos.Append;
            Recebidos.FieldByName('TCP_CLIENT').AsInteger       := CliId;
            Recebidos.FieldByName('IP').AsString                := GetPeerAddr;
            Recebidos.FieldByName('Porta').AsString             := GetPeerPort;
            Recebidos.FieldByName('ID').AsString                := Id;
            Recebidos.FieldByName('MsgSequencia').AsInteger     := 0;
            Recebidos.FieldByName('DataGrama').AsString         := 'login';
            Recebidos.FieldByName('Processado').AsBoolean       := False;

            Recebidos.Post;

         End

         //Senao Salva o Pacote para processar
         Else if id <> '' then
         Begin

            while Recebidos.ReadOnly do
            Begin
               Sleep(1);
               SalvaLog(Arq_Log,'Aguardando Destravar Arquivo Recebido: ');
            End;

            Inc(NumPackRec);

            Recebidos.Append;
            Recebidos.FieldByName('TCP_CLIENT').AsInteger           := CliId;
            Recebidos.FieldByName('IP').AsString                    := GetPeerAddr;
            Recebidos.FieldByName('Porta').AsString                 := GetPeerPort;
            Recebidos.FieldByName('ID').AsString                    := Id;
            Recebidos.FieldByName('MsgSequencia').AsInteger         := MsgSequencia;
            Recebidos.FieldByName('DataGrama').AsString             := LinhaRec;
            Recebidos.FieldByName('Processado').AsBoolean           := False;
            Recebidos.Post;

            //Atualiza pacotes recebidos / mensagens Enviadas deste cliente
            NumRecebido     := NumRecebido + 1;
            UltMensagem     := Now;

         End
         //Recebeu dados e não logou ainda ?
         Else if id = '' then
         Begin
            SalvaLog(Arq_Log,'Desconectando... Recebeu dados sem login:' + LinhaRec + ' - IP:Porta' + GetPeerAddr + ':' + GetPeerPort);
            CloseDelayed;
         End;

         If Protocolo = 'T' Then
            BytesIni  := BytesTot;

         For Contador := BytesIni to BytesTot-1 do
         if (CharInSet(RcvdPacket[Contador],Separadores)) then
            BytesIni := Contador + 1
         Else
            Break;

      End;


      //Envia ACK Se o Protocolo For = <T>
      if Protocolo = 'T' then
         Try
            SendStr(Char(0) + Char(0));
            if Debug in [1,5,9]  then
               SalvaLog(Arq_Log,'ACK Enviado: ' + GetPeerAddr + ':' + GetPeerPort );
         Except
            SalvaLog(Arq_Log,'Erro ao enviar ACK: ' + GetPeerAddr + ':' + GetPeerPort );
         End
      Else if login and (Cmd_Pos_login <> '') then
         Try
            SendStr(Cmd_Pos_Login + Chr(13) + Chr(10));
            if Debug in [1,5,9]  then
               SalvaLog(Arq_Log,'Enviado CMD_POS_LOGIN: ' + Cmd_Pos_Login );
         Except
            SalvaLog(Arq_Log,'Erro ao enviar CMD_POS_LOGIN: ' + Cmd_Pos_Login );
         End;

      Pacotes.Caption := InttoStr(NumpackRec);

   end;

end;
}
{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TTcpSrvForm.TimerGravacaoTimer(Sender: TObject);
Var Sql_Pendente:  TStringList;
Begin

Inc(Arq_ThreadId);
if Arq_ThreadId > Num_Threads then
   Arq_ThreadId := 0;

Recebidos.ReadOnly := True;

if Recebidos.RecordCount > 0  then
Begin

   Recebidos.SaveToFile ( ExtractFileDir(Application.ExeName) + '\inbox\'+ FormatDateTime('yyyy-mm-dd_hh-nn-ss',now) + '.' + Copy(Srv_Equipo,1,3) + FormatFloat('00',Arq_ThreadId));

//   NumRegistros := Recebidos.RecordCount;

   Recebidos.EmptyDataSet;
   Recebidos.Close;
   Recebidos.Open;


   Try
      Try
         Sql_Pendente :=  TStringList.Create;
         Sql_Pendente.text := GeraSqlStatus(StrtoInt(Srv_Port), 0, 0, 0, 1);
         if Sql_Pendente.Count > 0 then
         Begin
            Sql_Pendente.SaveToFile(ExtractFileDir(Application.ExeName) + '\Sql\'+ FormatDateTime('yyyy-mm-dd_hh-nn-ss',now) + '.' + Copy(Srv_Equipo,1,3) + FormatFloat('00',Arq_ThreadId));
            SalvaLog(Arq_Log,'Salvou SQL: ');
         End;
      Except;
         SalvaLog(Arq_Log,'Erro ao Salvar SQL: ' + GeraSqlStatus(StrtoInt(Srv_Port), 0, 0, 0, 1));
      End;
   Finally
      Sql_Pendente.Free;
   End;

End;

Recebidos.ReadOnly := False;

TcpSrvForm.Refresh;

//
//Vamos Fechar e Abrir  ?
{
StopTcpServer;
Sleep(1000);
StartTcpUdpServer;
}

end;

procedure TTcpSrvForm.TimerOutrosTimer(Sender: TObject);
Var Contador : Integer;
    Client: TTcpSrvClient;
begin
if Srv_proto = 'tcp' then
Begin
   if (WSocketServer1.ClientCount > 0)  then
      For Contador := WSocketServer1.ClientCount - 1 DownTo 0 do
      Begin

         Client := WSocketServer1.Client[Contador] as TTcpSrvClient;

         With Client as TTcpSrvClient do
         Begin
            //Se Conectado a mais de uma hora
            //Se Nao enviou mensagem na ultima hora
            if (((Now - UltMensagem)*24*60) > 60)  and
               (((Now - ConnectTime)*24*60) > 60)  then //tempo em minutos sem transmitir
               Client.Close
            //Se conectado a mais de 5 minutos e nao enviou mensagem
            Else if (((Now - UltMensagem)*24*60) > 5)  and
               (Id = '')  then
            Client.CloseDelayed;
         End;
      End;
end;

if srv_equipo = 'ACP' then
Begin

   if (Now - Thgravacao_acp_ultimo < 0.0007) then
      tGravacao.Glyph := tRunning.Glyph
   Else
      tGravacao.Glyph := tStoped.Glyph;

   if (Now - ThMsgAcp245_ultimo < 0.0007) then
      tMensagem.Glyph := tRunning.Glyph
   Else
      tMensagem.Glyph := tStoped.Glyph;

   if (Now - Thresultado_ultimo < 0.0007) then
      tResultado.Glyph := tRunning.Glyph
   Else
      tResultado.Glyph := tStoped.Glyph;

End
Else if srv_equipo = 'SATLIGHT' then
Begin

   if (Now - Thgravacao_satlight_ultimo < 0.0007) then
      tGravacao.Glyph := tRunning.Glyph
   Else
      tGravacao.Glyph := tStoped.Glyph;

   if (Now - ThMsgWebTech_ultimo < 0.0007) then
      tMensagem.Glyph := tRunning.Glyph
   Else
      tMensagem.Glyph := tStoped.Glyph;

   if (Now - ThResultado_ultimo < 0.0007) then
      tResultado.Glyph := tRunning.Glyph
   Else
      tResultado.Glyph := tStoped.Glyph;

End
Else if srv_equipo = 'WEBTECH' then
Begin

   if (Now - Thgravacao_webtech_ultimo < 0.0007) then
      tGravacao.Glyph := tRunning.Glyph
   Else
      tGravacao.Glyph := tStoped.Glyph;

   if (Now - ThMsgWebTech_ultimo < 0.0007) then
      tMensagem.Glyph := tRunning.Glyph
   Else
      tMensagem.Glyph := tStoped.Glyph;

   if (Now - ThResultado_ultimo < 0.0007) then
      tResultado.Glyph := tRunning.Glyph
   Else
      tResultado.Glyph := tStoped.Glyph;

End;
end;

{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{ This event handler is called when listening (server) socket experienced   }
{ a background exception. Should normally never occurs.                     }
{ tcp }
procedure TTcpSrvForm.WSocketServer1BgException(
   Sender       : TObject;
   E            : Exception;
   var CanClose : Boolean);
begin
   SalvaLog(Arq_Log,'Server exception occured: ' + E.ClassName + ': ' + E.Message);
   CanClose := FALSE;  { Hoping that server will still work ! }
end;
{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{ This event handler is called when listening (server) socket experienced   }
{ a background exception. Should normally never occurs.                     }
{ udp }
procedure TTcpSrvForm.WSocketUdpRecBgException(
   Sender       : TObject;
   E            : Exception;
   var CanClose : Boolean);
begin
   SalvaLog(Arq_Log,'Server exception occured: ' + E.ClassName + ': ' + E.Message);
   CanClose := FALSE;  { Hoping that server will still work ! }
end;

{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{ This event handler is called when a client socket experience a background }
{ exception. It is likely to occurs when client aborted connection and data }
{ has not been sent yet.                                                    }
procedure TTcpSrvForm.ClientBgException(
   Sender       : TObject;
   E            : Exception;
   var CanClose : Boolean);
begin
   SalvaLog(Arq_Log,'Client exception occured: ' + E.ClassName + ': ' + E.Message);
   CanClose := TRUE;   { Goodbye client ! }
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TTcpSrvForm.SpeedButton1Click(Sender: TObject);
Var  Client: TTcpSrvClient;
     Contador: Integer;
begin

if Srv_Proto = 'udp' then
   Exit;

If DBGrid1.Visible Then
Begin
   if Assigned(Conexoes) then
      Conexoes.Free;
   DataSource1.DataSet := nil;
   SpeedButton1.Caption := 'Mostrar Grid';
   DBGrid1.Visible := False;

   TcpSrvForm.Width  := 478;
   TcpSrvForm.Height := Altura;
   TcpSrvForm.Top    := Topo;
   TcpSrvForm.Left   := Esquerda;

End
Else
Begin

   TcpSrvForm.Width  := 640;
   TcpSrvForm.Height := 479;
   TcpSrvForm.Top    := 0;
   TcpSrvForm.Left   := 0;

   Conexoes := tClientDataSet.Create(Application);
   Conexoes.FieldDefs.Add('Sequencia', ftInteger, 0, False);
   Conexoes.FieldDefs.Add('ID', ftString, 20, False);
   Conexoes.FieldDefs.Add('IP', ftString, 15, False);
   Conexoes.FieldDefs.Add('Porta', ftInteger, 0, False);
   Conexoes.FieldDefs.Add('Pacotes', ftInteger, 0, False);
   Conexoes.FieldDefs.Add('Enviados', ftInteger, 0, False);
   Conexoes.FieldDefs.Add('Dt_ultimo', ftDateTime, 0, False);
   Conexoes.FieldDefs.Add('Firmware', ftString, 15, False);
   Conexoes.FieldDefs.Add('Proto', ftString, 1, False);
   Conexoes.FieldDefs.Add('Packet', ftString, 512, False);
   Conexoes.CreateDataSet;

   For Contador := 0 to WSocketServer1.ClientCount - 1  do
   Begin

      Client := WSocketServer1.Client[Contador] as TTcpSrvClient;

      With Client as TTcpSrvClient do
      Begin
         Conexoes.Append;
         Conexoes.FieldByName('Sequencia').AsInteger := CliId;
         Conexoes.FieldByName('ID').AsString := ID;
         Conexoes.FieldByName('IP').AsString := GetPeerAddr;
         Conexoes.FieldByName('Porta').AsString := GetPeerPort;
         Conexoes.FieldByName('Pacotes').AsInteger := NumRecebido;
         Conexoes.FieldByName('Enviados').AsInteger := NumMens;
         Conexoes.FieldByName('FirmWare').AsString := Firmware;
         Conexoes.FieldByName('Proto').AsString := Protocolo;

         if UltMensagem = 0  then
            Conexoes.FieldByName('Dt_Ultimo').Clear
         Else
            Conexoes.FieldByName('Dt_Ultimo').AsDateTime := UltMensagem;
         Conexoes.FieldByName('Packet').AsString := Copy(RcvdPacket,1,512);

         Conexoes.Post;
      End;
   End;

   DataSource1.DataSet := Conexoes;
   SpeedButton1.Caption := 'Ocultar Grid';
   DBGrid1.Visible := True;

End;
end;


procedure TTcpSrvForm.SpeedButton2Click(Sender: TObject);
begin

end;

{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TTcpSrvForm.leconfig;
Var nomearquivo: String;
var ArqIni: TInifile;
begin

Arq_Log              := ExtractFileDir(Application.ExeName) + '\logs\' + FormatDateTime('yyyy-mm-dd',now) + '.log';
Arq_SQL              := ExtractFilePath(Application.ExeName) + '\Logs\' + FormatDateTime('yyyy_mm_dd',Now) + '.sql';
NomeArquivo          := ChangeFileExt(Application.ExeName,'.ini');

If Not FileExists(nomearquivo) Then
Begin
   SalvaLog(Arq_Log,'Arquivo de Configuração não Encontrado: ' + name );
End;

ArqIni               := TIniFile.Create(nomearquivo);

DirInbox             := ExtractFileDir(Application.ExeName) + '\inbox';             //Diretorio arquivos recebidos a processar
DirProcess           := ExtractFileDir(Application.ExeName) + '\processa';          //Diretorio de arquivos recebidos e processados
DirErros             := ExtractFileDir(Application.ExeName) + '\erros';             //Diretorio de arquivos recebidos e Não Processados com Sucesso
DirSql               := ExtractFileDir(Application.ExeName) + '\sql';               //Diretorio de Comandos Sql não Executados
db_hostname          := ArqIni.ReadString('DATABASE' ,'HOST','IP_SERVIDOR');        //Ip do banco de dados
db_username          := ArqIni.ReadString('DATABASE' ,'USERNAME','USUARIO');        //usuario
db_password          := ArqIni.ReadString('DATABASE' ,'PASSWORD','SENHA');          //senha
db_database          := ArqIni.ReadString('DATABASE' ,'DATABASE','DATABASE_MYSQL'); //nome do database
db_inserts           := ArqIni.ReadInteger('DATABASE' ,'INSERTS',10);               //Inserts Simultaneo
cpr_db_hostname      := ArqIni.ReadString('CPR' ,'HOST','IP_SERVIDOR');             //Ip do banco de dados
cpr_db_username      := ArqIni.ReadString('CPR' ,'USERNAME','USUARIO');             //usuario
cpr_db_password      := ArqIni.ReadString('CPR' ,'PASSWORD','SENHA');               //senha
cpr_db_database      := ArqIni.ReadString('CPR' ,'DATABASE','CPR');                 //nome do database
Srv_Equipo           := ArqIni.ReadString('SERVER' ,'EQUIPAMENTO','ACP');           //Servidor Protocolo = tcp
Srv_Proto            := ArqIni.ReadString('SERVER' ,'PROTOCOLO','tcp');             //Servidor Protocolo = tcp
Srv_Port             := ArqIni.ReadString('SERVER' ,'PORT','9999');                 //Servidor Porta = 9999
Srv_Addr             := ArqIni.ReadString('SERVER' ,'ADDR','0.0.0.0');              //Servidor Listen = 0.0.0.0 // todas interfaces
debug                := ArqIni.ReadInteger('SERVER' ,'DEBUG',0);                    //Nivel e debug
cmd_pos_login        := ArqIni.ReadString('SERVER' ,'CMD_POS_LOGIN','');            //Comando a enviar apos o login
Topo                 := ArqIni.ReadInteger('SERVER' ,'TOPO',0);                     //Topo
Esquerda             := ArqIni.ReadInteger('SERVER' ,'ESQUERDA',250);               //Esquerda
Altura               := ArqIni.ReadInteger('SERVER' ,'ALTURA',117);                 //Altura
Timer_Arquivo        := ArqIni.ReadInteger('SERVER' ,'TIMER_ARQUIVO',5);            //Timer para Fechar arquivo
Num_Clientes         := ArqIni.ReadInteger('SERVER' ,'CLIENTES',50);                //Número máximo de clientes simultaneos
Num_Threads          := ArqIni.ReadInteger('SERVER' ,'THREADS',20);                 //Número máximo de threads de gravaçao
ArqIni.Free;

ForceDirectories(ExtractFileDir(Arq_Log));
ForceDirectories(DirInbox);
ForceDirectories(DirProcess);
ForceDirectories(DirErros);
ForceDirectories(DirSql);

end;


Procedure TTcpSrvForm.GravarPacote(pPacket: String);
//Var Busca: Variant;
Var Encontrado: Boolean;
begin

Encontrado := False;

AcpNews.First;
while Not AcpNews.Eof do
Begin
   if (AcpNews.FieldByName('Type').AsInteger = Ord(pPacket[1])) and
      (AcpNews.FieldByName('Size').AsInteger = Ord(pPacket[4])) then
   Begin
      Encontrado := True;
      AcpNews.Last;
   End;
   AcpNews.Next;
End;

if Not Encontrado then
Begin
   AcpNews.Append;
   AcpNews.FieldByName('Type').AsInteger     := Ord(pPacket[1]);
   AcpNews.FieldByName('Size').AsInteger     := Ord(pPacket[4]);
   AcpNews.FieldByName('PackeStr').AsString  := pPacket;
   AcpNews.Post;
End;

End;
end.

