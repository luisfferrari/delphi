{ *_* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
Author:       Fran?ois Piette
Creation:     Aug 29, 1999
Corretion:    Jun 15, 2011
Version:      7.01
Description:  Basic TCP server showing how to use TWSocketServer and
              TWSocketClient components and how to send binary data
              which requires OverbyteIcsBinCliDemo as client application.
EMail:        francois.piette@overbyte.be  http://www.overbyte.be
Support:      Use the mailing list twsocket@elists.org
              Follow "support" link at http://www.overbyte.be for subscription.
Legal issues: Copyright (C) 1999-2010 by Fran?ois PIETTE
              Rue de Grady 24, 4053 Embourg, Belgium.
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
May 2012 - V8.00 - this is a Windows , IPv4 only
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
unit Gateway_01;

interface

uses
   Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
   StdCtrls, IniFiles, Buttons, Grids, DateUtils, ExtCtrls, DB,
   DBClient, DBGrids, Contnrs, Types, Variants,
   OverbyteIcsWinSock, OverbyteIcsWSocket, OverbyteIcsWSocketS, OverbyteIcsWndControl,
   FuncColetor, FunQUECLINK, StrUtils, thread_gravacao_QUECLINK,
   thread_gravacao_acp245, thread_gravacao_webtech, thread_gravacao_quanta,
   thread_gravacao_satlight, thread_gravacao_quanta_acp, thread_gravacao_Suntech,
   thread_msgquanta, thread_resultado, thread_msgwebtech, thread_MsgAcp245,
   thread_gravacao_CalAmp, thread_msgsatlight, thread_Msgquanta_acp,
   thread_MsgSuntech, thread_MsgQUECLINK, thread_MsgCalAmp, thread_query, ZConnection, ZDataset, ZAbstractRODataset;

const
   TcpSrvVersion = 800;
   CopyRight = ' TcpSrv (c) 1999-2010 by Fran?ois PIETTE. V7.02';

type

   { TTcpSrvClient is the class which will be instanciated by server component }
   { for each new client. N simultaneous clients means N TTcpSrvClient will be }
   { instanciated. Each being used to handle only a single client. }
   { We can add any data that has to be private for each client, such as }
   { receive buffer or any other data needed for processing. }

   TTcpSrvClient = class(TWSocketClient)
   Public
      RcvdPacket: String;
      NovoPacket: String;
      Id: String;
      NumRecebido: Integer;
      NumMens: Integer;
      NumKeepAlive: Integer;
      ConnectTime: TDateTime;
      UltMensagem: TDateTime;
      Protocolo: String;
      FirmWare: String;
      Mensagem: String;
      MsgSequencia: Integer;
      PktSequencia: Integer;
      Duplicado: Integer;

      UltimoAck: TByteDynArray;
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
      TimerEstatisticas: TTimer;
    TimerContador: TTimer;

      procedure FormShow(Sender: TObject);
      procedure FormClose(Sender: TObject; var Action: TCloseAction);
      procedure FormCreate(Sender: TObject);
      procedure WSocketServer1ClientConnect(Sender: TObject; Client: TWSocketClient; Error: Word);
      procedure WSocketServer1ClientDisconnect(Sender: TObject; Client: TWSocketClient; Error: Word);
      procedure WSocketServer1BgException(Sender: TObject; E: Exception; var CanClose: Boolean);
      procedure DoSocksError(Sender: TObject; ErrCode: Integer; Msg: String);

      procedure leconfig;
      procedure TimerGravacaoTimer(Sender: TObject);
      procedure SpeedButton1Click(Sender: TObject);
      Procedure StartThreadGravacao;
      Procedure StartThreadMensagem;
      Procedure StartThreadResultado;
      Procedure StartThreadQuery;
      Procedure StopThreads;
      Procedure StopTcpUdpServer;
      procedure SpeedButton2Click(Sender: TObject);
      procedure TimerOutrosTimer(Sender: TObject);
      procedure TimerEstatisticasTimer(Sender: TObject);
      procedure tGravacaoClick(Sender: TObject);
      procedure TimerContadorTimer(Sender: TObject);
      Function RetiraAspaSimples(Texto:String):String;
   private
      Threadgravacao_Acp245: Array of gravacao_acp245;
      Threadgravacao_quanta_acp: Array of gravacao_quanta_acp;
      Threadgravacao_quanta: Array of gravacao_quanta;
      Threadgravacao_satlight: Array of gravacao_satlight;
      Threadgravacao_webtech: Array of gravacao_webtech;
      Threadgravacao_Suntech: Array of gravacao_Suntech;
      Threadgravacao_QUECLINK: Array of gravacao_QUECLINK;
      Threadgravacao_CalAmp: Array of gravacao_CalAmp;
      Threadresultado: Array of resultado;
      ThreadQuery: Array of dbquery;
      ThreadMsgAcp245: MsgAcp245;
      ThreadMsgQuanta_Acp: Msgquanta_Acp;
      ThreadMsgSatLight: MsgSatLight;
      ThreadMsgQuanta: MsgQuanta;
      ThreadMsgWebTech: MsgWebTech;
      ThreadMsgSuntech: MsgSuntech;
      ThreadMsgQUECLINK: MsgQUECLINK;
      ThreadMsgCalAmp: MsgCalAmp;
      RequerAck: Boolean;

      NumpackRec: Integer;
      NumPackEst: Integer;
      DirInbox: String;
      DirProcess: String;
      DirErros: String;
      DirErrosSql: String;
      DirSql: String;
      Arq_Log: String;
      Arq_Sql: String;
      db_hostname, db_username, db_password, db_database, db_tablecarga,
         cpr_db_hostname, cpr_db_username, cpr_db_password, cpr_db_database,
         Srv_Equipo, Srv_Proto, Srv_Port, Srv_Addr, cmd_pos_login: String;
      Altura, Topo, Esquerda: Integer;
      Debug: Shortint;
      Debug_ID,gravatemp,Debug_pct: String;
      Num_Threads, Num_Clientes, db_inserts, ErroLogin, marc_codigo,vcontador_arquivo,vquant_sql,
         Timer_Arquivo: Integer;
      Timer_estatisticas: Integer;
      WSocketServer1: TWSocketServer;
      WSocketUdpRec: TWSocket;
      WSocketUdpEnv: TWSocket;
      PacketRec: Array [0 .. 1500] of Byte;
      PacketRec_novo: Array [0 .. 1500] of Byte;
      vChar : array [0..1500] of char ;
      ServerStartUp: TDateTime;
      ServerReStartUp: TDateTime;
      Arq_ThreadId: Word;
      Encerrado: Boolean;
      Qry_ret: TZReadOnlyQuery; // Um objeto query local
      conn: TZConnection; // Uma tconnection local

      procedure StartTcpUdpServer;
      procedure WSocketUdpRecDataAvailable(Sender: TObject; Error: Word);
      procedure DataAvailable_Satlight(Sender:  TObject; Error: Word);
      procedure DataAvailable_Quanta(Sender:  TObject; Error: Word);
      procedure WSocketUdpRecSessionConnected(Sender: TObject; Error: Word);
      procedure WSocketUdpRecSessionClosed(Sender: TObject; Error: Word);
      procedure WSocketUdpRecBgException(Sender: TObject; E: Exception; var CanClose: Boolean);
      procedure WSocketUdpEnvDataSent(Sender: TObject; ErrCode: Word);

      procedure ClientDataAvailable_SATLIGHT_TCP(Sender: TObject; Error: Word);
      procedure ClientDataAvailable_ACP245(Sender: TObject; Error: Word);
      procedure ClientDataAvailable_Quanta_Acp(Sender: TObject; Error: Word);
      procedure ClientDataAvailable_WEBTECH(Sender: TObject; Error: Word);
      procedure ClientDataAvailable_SunTech(Sender: TObject; Error: Word);
      procedure ClientDataAvailable_QUECLINK(Sender: TObject; Error: Word);
      procedure ClientDataAvailable_CalAmp(Sender: TObject; Error: Word);
      procedure ClientDataAvailable_GENERICO(Sender: TObject; Error: Word);
      procedure ClientBgException(Sender: TObject; E: Exception; var CanClose: Boolean);
      procedure ClientLineLimitExceeded(Sender: TObject; Cnt: LongInt; var ClearData: Boolean);

   Public

      Recebidos: tClientDataSet;
      QuantaRec: tClientDataSet;
      Conexoes: tClientDataSet;
      MsgPendente: tClientDataSet;
      pacote: tClientDataSet;

      // Variaveis para a thread atualizar o ultimo ciclo
      Thgravacao_Acp245_ultimo: TDateTime;
      Thgravacao_Quanta_acp_ultimo: TDateTime;
      Thgravacao_Webtech_ultimo: TDateTime;
      Thgravacao_Satlight_ultimo: TDateTime;
      Thgravacao_SunTech_ultimo: TDateTime;
      Thgravacao_QUECLINK_ultimo: TDateTime;
      Thgravacao_CalAmp_ultimo: TDateTime;
      ThMsgWebTech_ultimo: TDateTime;
      ThMsgSuntech_ultimo: TDateTime;
      ThMsgQUECLINK_ultimo: TDateTime;
      ThMsgCalAmp_ultimo: TDateTime;
      ThMsgSatlight_ultimo: TDateTime;
      ThMsgQuanta_ultimo: TDateTime;
      ThMsgAcp245_ultimo: TDateTime;
      ThMsgquanta_Acp_ultimo: TDateTime;
      Thgravacao_Quanta_Ultimo: Array of TDateTime;
      Thresultado_Ultimo: TDateTime;
      Thdb_query_Ultimo: TDateTime;

      procedure RecebeResultado(pId: String; pClient: Integer; pIP, pPorta: String; pResposta: TStream);
      Function EnviaMsgWebTech(var Mensagens: tClientDataSet): Boolean;
      Function EnviaMsgSuntech(var Mensagens: tClientDataSet): Boolean;
      Function EnviaMsgQUECLINK(var Mensagens: tClientDataSet): Boolean;
      Function EnviaMsgCalAmp(var Mensagens: tClientDataSet): Boolean;
      Function EnviaMsgSatLight(var Mensagens: tClientDataSet): Boolean;
      Function EnviaMsgQuanta(var Mensagens: tClientDataSet): Boolean;
      Function EnviaMsgAcp245(var Mensagens: tClientDataSet): Boolean;
      Function EnviaMsgquanta_acp(var Mensagens: tClientDataSet): Boolean;
      Function HexToAscii(Hex: String): String;
      function ParImpar(aNum: Integer): Boolean;
      function ArrayToString(const a: array of Char): string;

   end;

var
   TcpSrvForm: TTcpSrvForm;
   contador_arquivo : integer;
   pacote_asc : string;
implementation

{$R *.DFM}

const
   SectionWindow = 'WindowTcpSrv';

   { * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
procedure TTcpSrvForm.FormCreate(Sender: TObject);
begin

{$IFDEF DELPHI10_UP}
   // BDS2006 has built-in memory leak detection and display
   ReportMemoryLeaksOnShutdown := (DebugHook <> 0);
{$ENDIF}
   Arq_ThreadId := 0;
   NumpackRec := 0;
   NumPackEst := 0;
   ErroLogin := 0;

   leconfig;

   Thgravacao_acp245_ultimo      := Now;
   Thgravacao_quanta_acp_ultimo  := Now;
   Thgravacao_satlight_ultimo    := Now;
   Thgravacao_webtech_ultimo     := Now;
   ThMsgWebTech_ultimo           := Now;
   ThMsgSatlight_ultimo          := Now;
   ThMsgAcp245_ultimo            := Now;
   ThMsgquanta_acp_ultimo        := Now;
   Thresultado_ultimo            := Now;

   SetLength(Threadgravacao_acp245, Num_Threads);
   SetLength(Threadgravacao_quanta_acp, Num_Threads);
   SetLength(Threadgravacao_quanta, Num_Threads);
   SetLength(Threadgravacao_satlight, Num_Threads);
   SetLength(Threadgravacao_webtech, Num_Threads);
   SetLength(Threadgravacao_SunTech, Num_Threads);
   SetLength(Threadgravacao_QUECLINK, Num_Threads);
   SetLength(Threadgravacao_CalAmp, Num_Threads);
   SetLength(Threadresultado, Num_Threads);
   SetLength(ThreadQuery, Num_Threads);
   SetLength(Thgravacao_quanta_ultimo, Num_Threads);
   // Definicao do Arquivo de gravacao dos dados recebidos
   Recebidos := tClientDataSet.Create(Application);

   if Srv_Equipo = 'ACP245' Then
   Begin
      Recebidos.FieldDefs.Add('Tcp_Client', ftInteger, 0, False);
      Recebidos.FieldDefs.Add('IP', ftString, 15, False);
      Recebidos.FieldDefs.Add('Porta', ftInteger, 0, False);
      Recebidos.FieldDefs.Add('ID', ftString, 20, False);
      Recebidos.FieldDefs.Add('MsgSequencia', ftInteger, 0, False);
      Recebidos.FieldDefs.Add('Datagrama', ftBlob, 0, False);
      Recebidos.FieldDefs.Add('Processado', ftBoolean, 0, False);
      Recebidos.FieldDefs.Add('Duplicado', ftInteger, 0, False);
      Recebidos.FieldDefs.Add('Data_rec', ftDateTime, 0, False);
      TcpSrvForm.Caption := 'Multi Gateway ACP245 - ' + Srv_Proto + ' : '
         + Srv_Port
   End
   Else if Srv_Equipo = 'QUANTA_ACP' Then
   Begin
      Recebidos.FieldDefs.Add('Tcp_Client', ftInteger, 0, False);
      Recebidos.FieldDefs.Add('IP', ftString, 15, False);
      Recebidos.FieldDefs.Add('Porta', ftInteger, 0, False);
      Recebidos.FieldDefs.Add('ID', ftString, 20, False);
      Recebidos.FieldDefs.Add('MsgSequencia', ftInteger, 0, False);
      Recebidos.FieldDefs.Add('Datagrama', ftBlob, 0, False);
      Recebidos.FieldDefs.Add('Processado', ftBoolean, 0, False);
      Recebidos.FieldDefs.Add('Duplicado', ftInteger, 0, False);
      TcpSrvForm.Caption := 'Multi Gateway Quanta-ACP - ' + Srv_Proto + ' : '
         + Srv_Port
   End
   Else if Srv_Equipo = 'WEBTECH' Then
   Begin
      Recebidos.FieldDefs.Add('Tcp_Client', ftInteger, 0, False);
      Recebidos.FieldDefs.Add('IP', ftString, 15, False);
      Recebidos.FieldDefs.Add('Porta', ftInteger, 0, False);
      Recebidos.FieldDefs.Add('ID', ftString, 20, False);
      Recebidos.FieldDefs.Add('MsgSequencia', ftInteger, 0, False);
      Recebidos.FieldDefs.Add('Datagrama', ftString, 1540, False);
      Recebidos.FieldDefs.Add('Processado', ftBoolean, 0, False);
      TcpSrvForm.Caption := 'Multi Gateway WEBTECH - ' + Srv_Proto + ' : ' + Srv_Port
   End
   Else if Srv_Equipo = 'SUNTECH' Then
   Begin
      Recebidos.FieldDefs.Add('Tcp_Client', ftInteger, 0, False);
      Recebidos.FieldDefs.Add('IP', ftString, 15, False);
      Recebidos.FieldDefs.Add('Porta', ftInteger, 0, False);
      Recebidos.FieldDefs.Add('ID', ftString, 20, False);
      Recebidos.FieldDefs.Add('MsgSequencia', ftInteger, 0, False);
      Recebidos.FieldDefs.Add('Datagrama', ftString, 1540, False);
      Recebidos.FieldDefs.Add('Processado', ftBoolean, 0, False);
      TcpSrvForm.Caption := 'Multi Gateway SunTech - ' + Srv_Proto + ' : ' + Srv_Port
   End
   Else if Srv_Equipo = 'QUECLINK' Then
   Begin
      pacote := tClientDataSet.Create(Application);
      pacote.FieldDefs.Add('ID', ftString, 20, False);
      pacote.FieldDefs.Add('pacote', ftString, 20, False);
      pacote.FieldDefs.Add('marc_codigo', ftInteger, 0, False);
      pacote.FieldDefs.Add('data_rec', ftDateTime, 0, False);
      pacote.CreateDataset;

      Recebidos.FieldDefs.Add('Tcp_Client', ftInteger, 0, False);
      Recebidos.FieldDefs.Add('IP', ftString, 15, False);
      Recebidos.FieldDefs.Add('Porta', ftInteger, 0, False);
      Recebidos.FieldDefs.Add('ID', ftString, 20, False);
      Recebidos.FieldDefs.Add('MsgSequencia', ftInteger, 0, False);
      Recebidos.FieldDefs.Add('Datagrama', ftString, 1540, False);
      Recebidos.FieldDefs.Add('Processado', ftBoolean, 0, False);
      TcpSrvForm.Caption := 'Multi Gateway QUECLINK - ' + Srv_Proto + ' : ' + Srv_Port
   End
   Else if Srv_Equipo = 'CALAMP' Then
   Begin
      Recebidos.FieldDefs.Add('Tcp_Client', ftInteger, 0, False);
      Recebidos.FieldDefs.Add('IP', ftString, 15, False);
      Recebidos.FieldDefs.Add('Porta', ftInteger, 0, False);
      Recebidos.FieldDefs.Add('ID', ftString, 20, False);
      Recebidos.FieldDefs.Add('MsgSequencia', ftInteger, 0, False);
      Recebidos.FieldDefs.Add('Datagrama', ftBlob, 0, False);
      Recebidos.FieldDefs.Add('Processado', ftBoolean, 0, False);
      Recebidos.FieldDefs.Add('Duplicado', ftInteger, 0, False);
      TcpSrvForm.Caption := 'Multi Gateway CalAmp - ' + Srv_Proto + ' : ' + Srv_Port
   End
   Else if Srv_Equipo = 'GENERICO' Then
   Begin
      Recebidos.FieldDefs.Add('Tcp_Client', ftInteger, 0, False);
      Recebidos.FieldDefs.Add('IP', ftString, 15, False);
      Recebidos.FieldDefs.Add('Porta', ftInteger, 0, False);
      Recebidos.FieldDefs.Add('ID', ftString, 20, False);
      Recebidos.FieldDefs.Add('MsgSequencia', ftInteger, 0, False);
      Recebidos.FieldDefs.Add('Datagrama', ftString, 1540, False);
      Recebidos.FieldDefs.Add('Processado', ftBoolean, 0, False);
      TcpSrvForm.Caption := 'Multi Gateway GENERICO - ' + Srv_Proto + ' : '
         + Srv_Port
   End
   Else if Srv_Equipo = 'QUANTA' Then
   Begin

      MsgPendente := tClientDataSet.Create(Application);
      MsgPendente.FieldDefs.Add('ID', ftString, 20, False);
      MsgPendente.FieldDefs.Add('IP_REMOTO', ftString, 20, False);
      MsgPendente.FieldDefs.Add('PORTA_REMOTO', ftInteger, 0, False);
      MsgPendente.FieldDefs.Add('Sequencia', ftInteger, 0, False);
      MsgPendente.FieldDefs.Add('Comando', ftString, 200, False);
      MsgPendente.FieldDefs.Add('Status', ftInteger, 0, False);
      MsgPendente.CreateDataset;

      Recebidos.FieldDefs.Add('IP', ftString, 15, False);
      Recebidos.FieldDefs.Add('Porta', ftInteger, 0, False);
      Recebidos.FieldDefs.Add('ID', ftString, 20, False);
      Recebidos.FieldDefs.Add('MsgSequencia', ftInteger, 0, False);
      Recebidos.FieldDefs.Add('Datagrama', ftBlob, 0, False);
      Recebidos.FieldDefs.Add('Produto', ftInteger, 0, False);
      Recebidos.FieldDefs.Add('Tipo', ftInteger, 0, False);
      Recebidos.FieldDefs.Add('Versao', ftInteger, 0, False);
      Recebidos.FieldDefs.Add('Duplicado', ftInteger, 0, False);
      Recebidos.FieldDefs.Add('Coderro', ftInteger, 0, False);

      QuantaRec := tClientDataSet.Create(Application);
      QuantaRec.FieldDefs.Add('ID', ftString, 20, False);
      QuantaRec.FieldDefs.Add('SeqRecebe', ftInteger, 0, False);
      QuantaRec.FieldDefs.Add('SeqEnvio', ftInteger, 0, False);
      QuantaRec.FieldDefs.Add('Datagrama', ftString, 1500, False);
      QuantaRec.FieldDefs.Add('Produto', ftInteger, 0, False);
      QuantaRec.FieldDefs.Add('Tipo', ftInteger, 0, False);
      QuantaRec.FieldDefs.Add('Versao', ftInteger, 0, False);
      QuantaRec.FieldDefs.Add('Duplicado', ftInteger, 0, False);
      QuantaRec.FieldDefs.Add('IP', ftString, 20, False);
      QuantaRec.FieldDefs.Add('Porta', ftString, 10, False);
      QuantaRec.CreateDataSet;
      QuantaRec.Addindex('Ind_Id', 'ID', [ixUnique]);
      QuantaRec.IndexName := 'Ind_Id';

      TcpSrvForm.Caption := 'Multi Gateway QUANTA - ' + Srv_Proto + ' : '
         + Srv_Port;
   End
   Else if Srv_Equipo = 'SATLIGHT' Then
   Begin

      MsgPendente := tClientDataSet.Create(Application);
      MsgPendente.FieldDefs.Add('ID', ftString, 20, False);
      MsgPendente.FieldDefs.Add('IP_REMOTO', ftString, 20, False);
      MsgPendente.FieldDefs.Add('PORTA_REMOTO', ftInteger, 0, False);
      MsgPendente.FieldDefs.Add('Sequencia', ftInteger, 0, False);
      MsgPendente.FieldDefs.Add('Mensagem', ftString, 1500, False);
      MsgPendente.FieldDefs.Add('Status', ftInteger, 0, False);
      MsgPendente.CreateDataset;

      Recebidos.FieldDefs.Add('Tcp_Client', ftInteger, 0, False);
      Recebidos.FieldDefs.Add('IP', ftString, 15, False);
      Recebidos.FieldDefs.Add('Porta', ftInteger, 0, False);
      Recebidos.FieldDefs.Add('ID', ftString, 20, False);
      Recebidos.FieldDefs.Add('MsgSequencia', ftInteger, 0, False);
      Recebidos.FieldDefs.Add('Datagrama', ftBlob, 0, False);
      Recebidos.FieldDefs.Add('Processado', ftBoolean, 0, False);
      TcpSrvForm.Caption := 'Multi Gateway SATLIGHT - ' + Srv_Proto + ' : '
         + Srv_Port;
   End;

   Recebidos.CreateDataset;

   TcpSrvForm.Width := 478;
   TcpSrvForm.Height := Altura;
   TcpSrvForm.Top := Topo;
   TcpSrvForm.Left := Esquerda;

   Encerrado := False;
   ServerStartUp := Now;
   ServerReStartUp := Now;

end;

{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
procedure TTcpSrvForm.StartTcpUdpServer;
begin
   try

      ServerReStartUp := Now;
      NumpackRec := 0;

      if Srv_Proto = 'tcp' then
      Begin

         WSocketServer1 := TWSocketServer.Create(TcpSrvForm);
         WSocketServer1.OnBgException        := WSocketServer1BgException;
         WSocketServer1.OnClientConnect      := WSocketServer1ClientConnect;
         WSocketServer1.OnClientDisconnect   := WSocketServer1ClientDisconnect;
         WSocketServer1.OnSocksError         := DoSocksError;
         WSocketServer1.MaxClients           := Num_Clientes;
         WSocketServer1.Banner               := '';
         WSocketServer1.Proto                := Srv_Proto; { Use TCP protocol }
         WSocketServer1.Port                 := Srv_Port; { Use telnet port }
         WSocketServer1.Addr                 := Srv_Addr; { Use any interface }
         WSocketServer1.LineMode             := False;
         WSocketServer1.LineEdit             := False;
         WSocketServer1.ClientClass          := TTcpSrvClient; { Use our component }
         WSocketServer1.Listen; { Start listening }
         SalvaLog(Arq_Log, 'Tcp Server Inicializado:  ');
      End
      // UDP
      Else
      Begin

         // Socket para recep??o UDP
         WSocketUdpRec := TWSocket.Create(TcpSrvForm);
         WSocketUdpRec.OnSessionConnected    := WSocketUdpRecSessionConnected;
         WSocketUdpRec.OnSessionClosed       := WSocketUdpRecSessionClosed;
         WSocketUdpRec.OnDataAvailable       := WSocketUdpRecDataAvailable;
         WSocketUdpRec.OnBgException         := WSocketUdpRecBgException;
//         WSocketServer1.OnSocksError         := DoSocksError;
         WSocketUdpRec.Proto                 := Srv_Proto; { Use TCP/UDP protocol }
         WSocketUdpRec.Port                  := Srv_Port; { Use srv_port }
         WSocketUdpRec.Addr                  := Srv_Addr; { Use srv_addr }
         WSocketUdpRec.LineMode              := False;
         WSocketUdpRec.LineEdit              := False;
         WSocketUdpRec.SocketFamily          := sfIPv4;
         WSocketUdpRec.Listen;  { Start listening }

         // Socket para envio do Ack
         WSocketUdpEnv := TWSocket.Create(TcpSrvForm);
         SalvaLog(Arq_Log, 'Udp Server Inicializado:  ');

      End;

   except

      SalvaLog(Arq_Log, 'Erro ao iniciar: StartTcpUdpServer ' );
      Self.Close;

   end;

end;

{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
procedure TTcpSrvForm.StopTcpUdpServer;
begin

   if Srv_Proto = 'tcp' then
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
            WSocketUdpEnv.Release;
      Except
         If Assigned(WSocketUdpRec) Then
            FreeAndNil(WSocketUdpRec);
         If Assigned(WSocketUdpEnv) Then
            FreeAndNil(WSocketUdpEnv);
      End;

   Sleep(1000);

   Try

      if Srv_Proto = 'tcp' then
      Begin
         If Assigned(WSocketServer1) Then
            FreeAndNil(WSocketServer1);
      End
      Else
      Begin
         If Assigned(WSocketUdpRec) Then
            FreeAndNil(WSocketUdpRec);
         If Assigned(WSocketUdpEnv) Then
            FreeAndNil(WSocketUdpEnv);
      End;

   Except
   End;

   SalvaLog(Arq_Log, 'Servi?os UDP/TCP Encerrados:');

end;

{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
Procedure TTcpSrvForm.StartThreadGravacao;
Var
   Contador: Word;
begin

   // Inicializa a thread de gravacao no banco de dados
   if Srv_Equipo = 'ACP245' then
   Begin
      for Contador := 0 to Num_Threads - 1 do
      Begin

         if Assigned(Threadgravacao_acp245[Contador]) then
            FreeAndNil(Threadgravacao_acp245[Contador]);

         Threadgravacao_acp245[Contador] := gravacao_acp245.Create(true);
         Threadgravacao_acp245[Contador].db_hostname := db_hostname;
         Threadgravacao_acp245[Contador].db_username := db_username;
         Threadgravacao_acp245[Contador].db_password := db_password;
         Threadgravacao_acp245[Contador].db_database := db_database;
         Threadgravacao_acp245[Contador].db_inserts := db_inserts;
         Threadgravacao_acp245[Contador].db_tablecarga := db_tablecarga;
         Threadgravacao_acp245[Contador].Debug := Debug;
         Threadgravacao_acp245[Contador].Debug_ID := Debug_ID;
         Threadgravacao_acp245[Contador].Arq_Log := Arq_Log;
         Threadgravacao_acp245[Contador].DirInbox := DirInbox;
         Threadgravacao_acp245[Contador].DirProcess := DirProcess;
         Threadgravacao_acp245[Contador].DirErros := DirErros;
         Threadgravacao_acp245[Contador].DirSql := DirSql;
         Threadgravacao_acp245[Contador].PortaLocal := StrToIntDef(Srv_Port,0);
         Threadgravacao_acp245[Contador].ServerStartUp := ServerReStartUp;
         Threadgravacao_acp245[Contador].ThreadId := Contador;
         Threadgravacao_acp245[Contador].Encerrar := False;
         Threadgravacao_acp245[Contador].FreeOnTerminate := true;
         // Destroi a thread quando terminar de executar
         Threadgravacao_acp245[Contador].Priority := tpnormal; // Prioridade Normal
         Threadgravacao_acp245[Contador].Resume; // Executa a thread

      End;
   End
   Else if Srv_Equipo = 'QUANTA_ACP' then
   Begin
      for Contador := 0 to Num_Threads - 1 do
      Begin

         if Assigned(Threadgravacao_QUANTA_ACP[Contador]) then
            FreeAndNil(Threadgravacao_quanta_acp[Contador]);

         Threadgravacao_quanta_acp[Contador] := gravacao_quanta_acp.Create(true);
         Threadgravacao_quanta_acp[Contador].db_hostname := db_hostname;
         Threadgravacao_quanta_acp[Contador].db_username := db_username;
         Threadgravacao_quanta_acp[Contador].db_password := db_password;
         Threadgravacao_quanta_acp[Contador].db_database := db_database;
         Threadgravacao_quanta_acp[Contador].db_inserts := db_inserts;
         Threadgravacao_quanta_acp[Contador].db_tablecarga := db_tablecarga;
         Threadgravacao_quanta_acp[Contador].Debug := Debug;
         Threadgravacao_quanta_acp[Contador].Debug_ID := Debug_ID;
         Threadgravacao_quanta_acp[Contador].Arq_Log := Arq_Log;
         Threadgravacao_quanta_acp[Contador].DirInbox := DirInbox;
         Threadgravacao_quanta_acp[Contador].DirProcess := DirProcess;
         Threadgravacao_quanta_acp[Contador].DirErros := DirErros;
         Threadgravacao_quanta_acp[Contador].DirSql := DirSql;
         Threadgravacao_quanta_acp[Contador].PortaLocal := StrToIntDef(Srv_Port,0);
         Threadgravacao_quanta_acp[Contador].ServerStartUp := ServerReStartUp;
         Threadgravacao_quanta_acp[Contador].ThreadId := Contador;
         Threadgravacao_quanta_acp[Contador].Encerrar := False;
         Threadgravacao_quanta_acp[Contador].FreeOnTerminate := true;
         // Destroi a thread quando terminar de executar
         Threadgravacao_quanta_acp[Contador].Priority := tpnormal; // Prioridade Normal
         Threadgravacao_quanta_acp[Contador].Resume; // Executa a thread

      End;
   End
   Else if Srv_Equipo = 'SATLIGHT' then
   Begin

      for Contador := 0 to Num_Threads - 1 do
      Begin

         If Assigned(Threadgravacao_satlight[Contador]) Then
            FreeAndNil(Threadgravacao_satlight[Contador]);

         Threadgravacao_satlight[Contador] := gravacao_satlight.Create(true);
         Threadgravacao_satlight[Contador].db_hostname := db_hostname;
         Threadgravacao_satlight[Contador].db_username := db_username;
         Threadgravacao_satlight[Contador].db_password := db_password;
         Threadgravacao_satlight[Contador].db_database := db_database;
         Threadgravacao_satlight[Contador].db_inserts := db_inserts;
         Threadgravacao_satlight[Contador].Debug := Debug;
         Threadgravacao_satlight[Contador].Arq_Log := Arq_Log;
         Threadgravacao_satlight[Contador].DirInbox := DirInbox;
         Threadgravacao_satlight[Contador].DirProcess := DirProcess;
         Threadgravacao_satlight[Contador].DirErros := DirErros;
         Threadgravacao_satlight[Contador].DirSql := DirSql;
         Threadgravacao_satlight[Contador].Encerrar := False;
         Threadgravacao_satlight[Contador].ThreadId := Contador;
         Threadgravacao_satlight[Contador].Srv_Proto := Srv_Proto;
         Threadgravacao_satlight[Contador].Srv_Addr := Srv_Addr;
         Threadgravacao_satlight[Contador].PortaLocal := StrToIntDef(Srv_Port,0);
         Threadgravacao_satlight[Contador].FreeOnTerminate := true;
         // Destroi a thread quando terminar de executar
         Threadgravacao_satlight[Contador].Priority := tpnormal;
         // Prioridade Normal
         Threadgravacao_satlight[Contador].Resume; // Executa a thread

      End;
   End
   Else if Srv_Equipo = 'WEBTECH' then
   Begin

      for Contador := 0 to Num_Threads - 1 do
      Begin

         If Assigned(Threadgravacao_webtech[Contador]) Then
            Threadgravacao_webtech[Contador].Free;

         Threadgravacao_webtech[Contador]             := gravacao_webtech.Create(true);
         Threadgravacao_webtech[Contador].db_hostname := db_hostname;
         Threadgravacao_webtech[Contador].db_username := db_username;
         Threadgravacao_webtech[Contador].db_password := db_password;
         Threadgravacao_webtech[Contador].db_database := db_database;
         Threadgravacao_webtech[Contador].db_inserts  := db_inserts;
         Threadgravacao_webtech[Contador].PortaLocal  := StrTointDef(Srv_Port,0);
         Threadgravacao_webtech[Contador].Debug       := Debug;
         Threadgravacao_webtech[Contador].Arq_Log     := Arq_Log;
         Threadgravacao_webtech[Contador].DirInbox    := DirInbox;
         Threadgravacao_webtech[Contador].DirProcess  := DirProcess;
         Threadgravacao_webtech[Contador].DirErros    := DirErros;
         Threadgravacao_webtech[Contador].DirSql      := DirSql;
         Threadgravacao_webtech[Contador].Encerrar    := False;
         Threadgravacao_webtech[Contador].ThreadId    := Contador;
         Threadgravacao_webtech[Contador].FreeOnTerminate := true;
         // Destroi a thread quando terminar de executar
         Threadgravacao_webtech[Contador].Priority    := tpnormal;
         // Prioridade Normal
         Threadgravacao_webtech[Contador].Resume; // Executa a thread
      End;
   End
   Else if Srv_Equipo = 'SUNTECH' then
   Begin

      for Contador := 0 to Num_Threads - 1 do
      Begin

         If Assigned(Threadgravacao_SunTech[Contador]) Then
            Threadgravacao_SunTech[Contador].Free;

         Threadgravacao_SunTech[Contador]                 := gravacao_SunTech.Create(true);
         Threadgravacao_SunTech[Contador].db_hostname     := db_hostname;
         Threadgravacao_SunTech[Contador].db_username     := db_username;
         Threadgravacao_SunTech[Contador].db_password     := db_password;
         Threadgravacao_SunTech[Contador].db_database     := db_database;
         Threadgravacao_SunTech[Contador].db_inserts      := db_inserts;
         Threadgravacao_SunTech[Contador].db_tablecarga   := db_tablecarga;
         Threadgravacao_SunTech[Contador].marc_codigo     := InttoStr(marc_codigo);

         Threadgravacao_SunTech[Contador].PortaLocal      := StrTointDef(Srv_Port,0);
         Threadgravacao_SunTech[Contador].Debug           := Debug;
         Threadgravacao_SunTech[Contador].Debug_ID        := Debug_id;
         Threadgravacao_SunTech[Contador].Arq_Log         := Arq_Log;
         Threadgravacao_SunTech[Contador].DirInbox        := DirInbox;
         Threadgravacao_SunTech[Contador].DirProcess      := DirProcess;
         Threadgravacao_SunTech[Contador].DirErros        := DirErros;
         Threadgravacao_SunTech[Contador].DirSql          := DirSql;
         Threadgravacao_SunTech[Contador].Encerrar        := False;
         Threadgravacao_SunTech[Contador].ThreadId        := Contador;
         Threadgravacao_SunTech[Contador].FreeOnTerminate := true;
         // Destroi a thread quando terminar de executar
         Threadgravacao_SunTech[Contador].Priority    := tpnormal;
         // Prioridade Normal
         Threadgravacao_SunTech[Contador].Resume; // Executa a thread
      End;
   End
   Else if Srv_Equipo = 'QUECLINK' then
   Begin

      for Contador := 0 to Num_Threads - 1 do
      Begin

         If Assigned(Threadgravacao_QUECLINK[Contador]) Then
            Threadgravacao_QUECLINK[Contador].Free;

         Threadgravacao_QUECLINK[Contador]                 := gravacao_QUECLINK.Create(true);
         Threadgravacao_QUECLINK[Contador].db_hostname     := db_hostname;
         Threadgravacao_QUECLINK[Contador].db_username     := db_username;
         Threadgravacao_QUECLINK[Contador].db_password     := db_password;
         Threadgravacao_QUECLINK[Contador].db_database     := db_database;
         Threadgravacao_QUECLINK[Contador].db_inserts      := db_inserts;
         Threadgravacao_QUECLINK[Contador].db_tablecarga   := db_tablecarga;
         Threadgravacao_QUECLINK[Contador].marc_codigo     := InttoStr(marc_codigo);

         Threadgravacao_QUECLINK[Contador].PortaLocal      := StrTointDef(Srv_Port,0);
         Threadgravacao_QUECLINK[Contador].Debug           := Debug;
         Threadgravacao_QUECLINK[Contador].Debug_ID        := Debug_id;
         Threadgravacao_QUECLINK[Contador].Debug_PCT       := Debug_pct;
         Threadgravacao_QUECLINK[Contador].gravatemp       := gravatemp;
         Threadgravacao_QUECLINK[Contador].contador_arquivo:= vcontador_arquivo;
         Threadgravacao_QUECLINK[Contador].quant_sql       := vquant_sql;
         Threadgravacao_QUECLINK[Contador].Arq_Log         := Arq_Log;
         Threadgravacao_QUECLINK[Contador].DirInbox        := DirInbox;
         Threadgravacao_QUECLINK[Contador].DirProcess      := DirProcess;
         Threadgravacao_QUECLINK[Contador].DirErros        := DirErros;
         Threadgravacao_QUECLINK[Contador].DirSql          := DirSql;
         Threadgravacao_QUECLINK[Contador].Encerrar        := False;
         Threadgravacao_QUECLINK[Contador].ThreadId        := Contador;
         Threadgravacao_QUECLINK[Contador].FreeOnTerminate := true;
         // Destroi a thread quando terminar de executar
         Threadgravacao_QUECLINK[Contador].Priority    := tpnormal;
         // Prioridade Normal
         Threadgravacao_QUECLINK[Contador].Resume; // Executa a thread
      End;
   End
   Else if Srv_Equipo = 'CALAMP' then
   Begin

      for Contador := 0 to Num_Threads - 1 do
      Begin

         If Assigned(Threadgravacao_CalAmp[Contador]) Then
            Threadgravacao_CalAmp[Contador].Free;

         Threadgravacao_CalAmp[Contador]                 := gravacao_CalAmp.Create(true);
         Threadgravacao_CalAmp[Contador].db_hostname     := db_hostname;
         Threadgravacao_CalAmp[Contador].db_username     := db_username;
         Threadgravacao_CalAmp[Contador].db_password     := db_password;
         Threadgravacao_CalAmp[Contador].db_database     := db_database;
         Threadgravacao_CalAmp[Contador].db_inserts      := db_inserts;
         Threadgravacao_CalAmp[Contador].db_tablecarga   := db_tablecarga;
         Threadgravacao_CalAmp[Contador].marc_codigo     := InttoStr(marc_codigo);

         Threadgravacao_CalAmp[Contador].PortaLocal      := StrTointDef(Srv_Port,0);
         Threadgravacao_CalAmp[Contador].Debug           := Debug;
         Threadgravacao_CalAmp[Contador].Debug_ID        := Debug_id;
         Threadgravacao_CalAmp[Contador].Arq_Log         := Arq_Log;
         Threadgravacao_CalAmp[Contador].DirInbox        := DirInbox;
         Threadgravacao_CalAmp[Contador].DirProcess      := DirProcess;
         Threadgravacao_CalAmp[Contador].DirErros        := DirErros;
         Threadgravacao_CalAmp[Contador].DirSql          := DirSql;
         Threadgravacao_CalAmp[Contador].Encerrar        := False;
         Threadgravacao_CalAmp[Contador].ThreadId        := Contador;
         Threadgravacao_CalAmp[Contador].FreeOnTerminate := true;
         // Destroi a thread quando terminar de executar
         Threadgravacao_CalAmp[Contador].Priority    := tpnormal;
         // Prioridade Normal
         Threadgravacao_CalAmp[Contador].Resume; // Executa a thread
      End;
   End
   Else if Srv_Equipo = 'QUANTA' then
   Begin
      for Contador := 0 to Num_Threads - 1 do
      Begin

         if Assigned(Threadgravacao_quanta[Contador]) then
            FreeAndNil(Threadgravacao_quanta[Contador]);

         Threadgravacao_quanta[Contador] := gravacao_quanta.Create(true);
         Threadgravacao_quanta[Contador].db_hostname     := db_hostname;
         Threadgravacao_quanta[Contador].db_username     := db_username;
         Threadgravacao_quanta[Contador].db_password     := db_password;
         Threadgravacao_quanta[Contador].db_database     := db_database;
         Threadgravacao_quanta[Contador].db_inserts      := db_inserts;
         Threadgravacao_quanta[Contador].db_tablecarga   := db_tablecarga;
         Threadgravacao_quanta[Contador].Debug           := Debug;
         Threadgravacao_quanta[Contador].Debug_ID        := Debug_ID;
         Threadgravacao_quanta[Contador].Arq_Log         := Arq_Log;
         Threadgravacao_quanta[Contador].DirInbox        := DirInbox;
         Threadgravacao_quanta[Contador].DirProcess      := DirProcess;
         Threadgravacao_quanta[Contador].DirErros        := DirErros;
         Threadgravacao_quanta[Contador].DirSql          := DirSql;
         Threadgravacao_quanta[Contador].PortaLocal      := StrToIntDef(Srv_Port,0);
         Threadgravacao_quanta[Contador].ServerStartUp   := ServerReStartUp;
         Threadgravacao_quanta[Contador].ThreadId        := Contador;
         Threadgravacao_quanta[Contador].Encerrar        := False;
         Threadgravacao_quanta[Contador].FreeOnTerminate := true;     // Destroi a thread quando terminar de executar
         Threadgravacao_quanta[Contador].Priority        := tpnormal; // Prioridade Normal
         Threadgravacao_quanta[Contador].Resume;                      // Executa a thread

      End;
   End

End;

{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
Procedure TTcpSrvForm.StartThreadMensagem;
Begin
   if Srv_Equipo = 'ACP245' then
   Begin
      if Assigned(ThreadMsgAcp245) then
         ThreadMsgAcp245.Terminate;

      // Inicializa a thread de envio de mensagens
      ThreadMsgAcp245                 := MsgAcp245.Create(true);
      ThreadMsgAcp245.db_hostname     := db_hostname;
      ThreadMsgAcp245.db_username     := db_username;
      ThreadMsgAcp245.db_password     := db_password;
      ThreadMsgAcp245.db_database     := db_database;
      ThreadMsgAcp245.cpr_db_hostname := cpr_db_hostname;
      ThreadMsgAcp245.cpr_db_username := cpr_db_username;
      ThreadMsgAcp245.cpr_db_password := cpr_db_password;
      ThreadMsgAcp245.cpr_db_database := cpr_db_database;
      ThreadMsgAcp245.Srv_Equipo      := Srv_Equipo;
      ThreadMsgAcp245.Arq_Log         := Arq_Log;
      ThreadMsgAcp245.Encerrar        := False;
      ThreadMsgAcp245.FreeOnTerminate := true;
      // Destroi a thread quando terminar de executar
      ThreadMsgAcp245.Priority        := tpnormal; // Prioridade Normal
      ThreadMsgAcp245.PortaLocal      := Srv_Port;
      ThreadMsgAcp245.Debug           := Debug;
      ThreadMsgAcp245.Debug_ID        := Debug_ID;
      ThreadMsgAcp245.Resume; // Executa a thread

   end
   Else if Srv_Equipo = 'QUANTA' then
   Begin
      if Assigned(ThreadMsgQuanta) then
         ThreadMsgQuanta.Terminate;

      // Inicializa a thread de envio de mensagens
      ThreadMsgQuanta                 := msgQuanta.Create(true);
      ThreadMsgQuanta.db_hostname     := db_hostname;
      ThreadMsgQuanta.db_username     := db_username;
      ThreadMsgQuanta.db_password     := db_password;
      ThreadMsgQuanta.db_database     := db_database;
      ThreadMsgQuanta.Srv_Equipo      := Srv_Equipo;
      ThreadMsgQuanta.Arq_Log         := Arq_Log;
      ThreadMsgQuanta.Encerrar        := False;
      ThreadMsgQuanta.FreeOnTerminate := true;
      // Destroi a thread quando terminar de executar
      ThreadMsgQuanta.Priority        := tpnormal; // Prioridade Normal
      ThreadMsgQuanta.PortaLocal      := Srv_Port;
      ThreadMsgQuanta.Debug           := Debug;
      ThreadMsgQuanta.Debug_ID        := Debug_ID;
      ThreadMsgQuanta.Resume; // Executa a thread

   end
   Else if Srv_Equipo = 'QUANTA_ACP' then
   Begin
      if Assigned(ThreadMsgQuanta_Acp) then
         ThreadMsgQuanta_Acp.Terminate;

      // Inicializa a thread de envio de mensagens
      ThreadMsgQuanta_Acp                 := MsgQuanta_acp.Create(true);
      ThreadMsgQuanta_Acp.db_hostname     := db_hostname;
      ThreadMsgQuanta_Acp.db_username     := db_username;
      ThreadMsgQuanta_Acp.db_password     := db_password;
      ThreadMsgQuanta_Acp.db_database     := db_database;
      ThreadMsgQuanta_Acp.cpr_db_hostname := cpr_db_hostname;
      ThreadMsgQuanta_Acp.cpr_db_username := cpr_db_username;
      ThreadMsgQuanta_Acp.cpr_db_password := cpr_db_password;
      ThreadMsgQuanta_Acp.cpr_db_database := cpr_db_database;
      ThreadMsgQuanta_Acp.Srv_Equipo      := Srv_Equipo;
      ThreadMsgQuanta_Acp.Arq_Log         := Arq_Log;
      ThreadMsgQuanta_Acp.Encerrar        := False;
      ThreadMsgQuanta_Acp.FreeOnTerminate := true;
      // Destroi a thread quando terminar de executar
      ThreadMsgQuanta_Acp.Priority        := tpnormal; // Prioridade Normal
      ThreadMsgQuanta_Acp.PortaLocal      := Srv_Port;
      ThreadMsgQuanta_Acp.Debug           := Debug;
      ThreadMsgQuanta_Acp.Debug_ID        := Debug_ID;
      ThreadMsgQuanta_Acp.Resume; // Executa a thread

   end
   Else if Srv_Equipo = 'WEBTECH' then
   Begin

      if Assigned(ThreadMsgWebTech) then
         ThreadMsgWebTech.Terminate;

      // Inicializa a thread de envio de mensagens
      ThreadMsgWebTech := MsgWebTech.Create(true);
      ThreadMsgWebTech.db_hostname     := db_hostname;
      ThreadMsgWebTech.db_username     := db_username;
      ThreadMsgWebTech.db_password     := db_password;
      ThreadMsgWebTech.db_database     := db_database;
      ThreadMsgWebTech.Srv_Equipo      := Srv_Equipo;
      ThreadMsgWebTech.Arq_Log         := Arq_Log;
      ThreadMsgWebTech.Encerrar        := False;
      ThreadMsgWebTech.FreeOnTerminate := true;
      // Destroi a thread quando terminar de executar
      ThreadMsgWebTech.Priority        := tpnormal; // Prioridade Normal
      ThreadMsgWebTech.PortaLocal      := Srv_Port;
      ThreadMsgWebTech.Debug           := Debug;
      ThreadMsgWebTech.Resume; // Executa a thread

   End
   Else if Srv_Equipo = 'SUNTECH' then
   Begin

      if Assigned(ThreadMsgSunTech) then
         ThreadMsgSunTech.Terminate;

      // Inicializa a thread de envio de mensagens
      ThreadMsgSunTech                 := MsgSunTech.Create(true);
      ThreadMsgSunTech.db_hostname     := db_hostname;
      ThreadMsgSunTech.db_username     := db_username;
      ThreadMsgSunTech.db_password     := db_password;
      ThreadMsgSunTech.db_database     := db_database;
      ThreadMsgSunTech.Srv_Equipo      := Srv_Equipo;
      ThreadMsgSunTech.Arq_Log         := Arq_Log;
      ThreadMsgSunTech.Encerrar        := False;
      ThreadMsgSunTech.FreeOnTerminate := true;
      // Destroi a thread quando terminar de executar
      ThreadMsgSunTech.Priority        := tpnormal; // Prioridade Normal
      ThreadMsgSunTech.PortaLocal      := Srv_Port;
      ThreadMsgSunTech.Debug           := Debug;
      ThreadMsgSunTech.Resume; // Executa a thread

   End
   Else if Srv_Equipo = 'QUECLINK' then
   Begin

      if Assigned(ThreadMsgQUECLINK) then
         ThreadMsgQUECLINK.Terminate;

      // Inicializa a thread de envio de mensagens
      ThreadMsgQUECLINK                 := MsgQUECLINK.Create(true);
      ThreadMsgQUECLINK.db_hostname     := db_hostname;
      ThreadMsgQUECLINK.db_username     := db_username;
      ThreadMsgQUECLINK.db_password     := db_password;
      ThreadMsgQUECLINK.db_database     := db_database;
      ThreadMsgQUECLINK.Srv_Equipo      := Srv_Equipo;
      ThreadMsgQUECLINK.Arq_Log         := Arq_Log;
      ThreadMsgQUECLINK.Encerrar        := False;
      ThreadMsgQUECLINK.FreeOnTerminate := true;
      // Destroi a thread quando terminar de executar
      ThreadMsgQUECLINK.Priority        := tpnormal; // Prioridade Normal
      ThreadMsgQUECLINK.PortaLocal      := Srv_Port;
      ThreadMsgQUECLINK.Debug           := Debug;
      ThreadMsgQUECLINK.Resume; // Executa a thread

   End
   Else if Srv_Equipo = 'CALAMP' then
   Begin

      if Assigned(ThreadMsgCalAmp) then
         ThreadMsgCalAmp.Terminate;

      // Inicializa a thread de envio de mensagens
      ThreadMsgCalAmp                 := MsgCalAmp.Create(true);
      ThreadMsgCalAmp.db_hostname     := db_hostname;
      ThreadMsgCalAmp.db_username     := db_username;
      ThreadMsgCalAmp.db_password     := db_password;
      ThreadMsgCalAmp.db_database     := db_database;
      ThreadMsgCalAmp.Srv_Equipo      := Srv_Equipo;
      ThreadMsgCalAmp.Arq_Log         := Arq_Log;
      ThreadMsgCalAmp.Encerrar        := False;
      ThreadMsgCalAmp.FreeOnTerminate := true;
      // Destroi a thread quando terminar de executar
      ThreadMsgCalAmp.Priority        := tpnormal; // Prioridade Normal
      ThreadMsgCalAmp.PortaLocal      := Srv_Port;
      ThreadMsgCalAmp.Debug           := Debug;
      ThreadMsgCalAmp.Resume; // Executa a thread

   End
   Else if Srv_Equipo = 'SATLIGHT' then
   Begin

      if Assigned(ThreadMsgSatLight) then
         ThreadMsgSatLight.Terminate;

      // Inicializa a thread de envio de mensagens
      ThreadMsgSatLight := MsgSatLight.Create(true);
      ThreadMsgSatLight.db_hostname     := db_hostname;
      ThreadMsgSatLight.db_username     := db_username;
      ThreadMsgSatLight.db_password     := db_password;
      ThreadMsgSatLight.db_database     := db_database;
      ThreadMsgSatLight.Srv_Equipo      := Srv_Equipo;
      ThreadMsgSatLight.Arq_Log         := Arq_Log;
      ThreadMsgSatLight.Encerrar        := False;
      ThreadMsgSatLight.FreeOnTerminate := true;
      // Destroi a thread quando terminar de executar
      ThreadMsgSatLight.Priority        := tpnormal; // Prioridade Normal
      ThreadMsgSatLight.PortaLocal      := Srv_Port;
      ThreadMsgSatLight.Debug           := Debug;
      ThreadMsgSatLight.Resume; // Executa a thread

   End;

End;

{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
Procedure TTcpSrvForm.StartThreadResultado;
Var
   Contador: Word;
Begin
   for Contador := 0 to Num_Threads - 1 do
   Begin
      if Assigned(Threadresultado[Contador]) then
         Threadresultado[Contador].Free;
      // Inicializa a thread de resultados da Gravacao
      Threadresultado[Contador]                 := resultado.Create(true);
      Threadresultado[Contador].Arq_Log         := Arq_Log;
      Threadresultado[Contador].DirProcess      := DirProcess;
      Threadresultado[Contador].ServerStartUp   := ServerReStartUp;
      Threadresultado[Contador].ThreadId        := Contador;
      Threadresultado[Contador].Encerrar        := False;
      Threadresultado[Contador].FreeOnTerminate := true;
      // Destroi a thread quando terminar de executar
      Threadresultado[Contador].Priority        := tpnormal; // Prioridade Normal
      Threadresultado[Contador].Resume; // Executa a thread
   End;

End;

{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
Procedure TTcpSrvForm.StartThreadQuery;
Var
   Contador: Word;
Begin

   for Contador := 0 to Num_Threads - 1 do
   Begin
      if Assigned(ThreadQuery[Contador]) then
         FreeAndNil(ThreadQuery[Contador]);
      // Inicializa a thread de Gravacao no banco de dados
      ThreadQuery[Contador] := dbquery.Create(true);
      ThreadQuery[Contador].db_hostname     := db_hostname;
      ThreadQuery[Contador].db_username     := db_username;
      ThreadQuery[Contador].db_password     := db_password;
      ThreadQuery[Contador].db_database     := db_database;
      ThreadQuery[Contador].Arq_Log         := Arq_Log;
      ThreadQuery[Contador].DirSql          := DirSql;
      ThreadQuery[Contador].DirErrosSql     := DirErrosSql;
      ThreadQuery[Contador].Encerrar        := False;
      ThreadQuery[Contador].Debug           := Debug;
      ThreadQuery[Contador].ThreadId        := Contador;
      ThreadQuery[Contador].FreeOnTerminate := true;     // Destroi a thread quando terminar de executar
      ThreadQuery[Contador].Priority        := tpnormal; // Prioridade Normal
      ThreadQuery[Contador].Resume;                      // Executa a thread
   End;

End;

{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
Procedure TTcpSrvForm.StopThreads;
Var
   Contador: Word;
begin
   Try

      for Contador := 0 to Num_Threads - 1 do
      Begin
         If Assigned(ThreadQuery[Contador]) Then
            ThreadQuery[Contador].Encerrar := true;
         if (RequerAck) and (Assigned(Threadresultado[Contador])) then
            Threadresultado[Contador].Encerrar := true;
      End;

      // Encerra a thread de gravacao no banco de dados
      if Srv_Equipo = 'ACP245' then
      Begin

         for Contador := 0 to Num_Threads - 1 do
            Threadgravacao_acp245[Contador].Encerrar := true;

      End
      Else if Srv_Equipo = 'QUANTA_ACP' then
      Begin

         for Contador := 0 to Num_Threads - 1 do
            Threadgravacao_Quanta_Acp[Contador].Encerrar := true;

      End
      Else if Srv_Equipo = 'SATLIGHT' then
      Begin

         for Contador := 0 to Num_Threads - 1 do
         Begin
            Threadgravacao_satlight[Contador].Encerrar := true;
         End;

      End
      Else if Srv_Equipo = 'WEBTECH' then
      Begin
         for Contador := 0 to Num_Threads - 1 do
            Threadgravacao_webtech[Contador].Encerrar := true;
      End
      Else if Srv_Equipo = 'SUNTECH' then
      Begin
         for Contador := 0 to Num_Threads - 1 do
            Threadgravacao_SunTech[Contador].Encerrar := true;
      End
      Else if Srv_Equipo = 'QUECLINK' then
      Begin
         for Contador := 0 to Num_Threads - 1 do
            Threadgravacao_QUECLINK[Contador].Encerrar := true;
      End
      Else if Srv_Equipo = 'CALAMP' then
      Begin
         for Contador := 0 to Num_Threads - 1 do
            Threadgravacao_CalAmp[Contador].Encerrar := true;
      End
      Else if Srv_Equipo = 'QUANTA' then
      Begin
         for Contador := 0 to Num_Threads - 1 do
            Threadgravacao_quanta[Contador].Encerrar := true;
      End;

      if Srv_Equipo = 'ACP245' then
      Begin
         If Assigned(ThreadMsgAcp245) Then
            ThreadMsgAcp245.Encerrar := true;
      End
      Else if Srv_Equipo = 'QUANTA' then
      Begin
         If Assigned(ThreadMsgQuanta) Then
            ThreadMsgQuanta.Encerrar := true;
      End
      Else if Srv_Equipo = 'QUANTA_ACP' then
      Begin
         If Assigned(ThreadMsgQuanta_Acp) Then
            ThreadMsgQuanta_Acp.Encerrar := true;
      End
      Else if Srv_Equipo = 'WEBTECH' then
      Begin
         If Assigned(ThreadMsgWebTech) Then
            ThreadMsgWebTech.Encerrar := true;
      End
      Else if Srv_Equipo = 'SUNTECH' then
      Begin
         If Assigned(ThreadMsgSunTech) Then
            ThreadMsgSunTech.Encerrar := true;
      End
      Else if Srv_Equipo = 'QUECLINK' then
      Begin
         If Assigned(ThreadMsgQUECLINK) Then
            ThreadMsgQUECLINK.Encerrar := true;
      End
      Else if Srv_Equipo = 'CALAMP' then
      Begin
         If Assigned(ThreadMsgCalAmp) Then
            ThreadMsgCalAmp.Encerrar := true;
      End
      Else if Srv_Equipo = 'SATLIGHT' then
      Begin
         If Assigned(ThreadMsgSatLight) Then
            ThreadMsgSatLight.Encerrar := true;
      End;

      Sleep(5000);

   Except

   End;
End;

procedure TTcpSrvForm.tGravacaoClick(Sender: TObject);
begin

end;

{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
procedure TTcpSrvForm.FormShow(Sender: TObject);
begin

   StartTcpUdpServer;

   StartThreadGravacao;
   StartThreadMensagem;
   StartThreadQuery;

   if RequerAck Then
      StartThreadResultado;

   Sleep(10);

   TimerGravacao.Interval     := Timer_Arquivo * 1000;
   TimerGravacao.Enabled      := true;
   TimerOutros.Enabled        := true;
   TimerEstatisticas.Interval := Timer_estatisticas * 1000;
   TimerEstatisticas.Enabled  := true;
   TimerContador.Interval     := vcontador_arquivo;
   TimerContador.Enabled      := true;

   TimerOutrosTimer(Self);

end;

{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
procedure TTcpSrvForm.FormClose(Sender: TObject; var Action: TCloseAction);
Var
   Contador: Word;
Begin

   if Encerrado Then
   Begin
      Application.Terminate;
      Action := caFree;
      Exit;
   End;

   Encerrado := true;

   Try

      // Primeiro tem que fechar o resultado a gravar no tcp Server...
      // Depois o TCP Server
      // Depois as threads de gravacao...

      for Contador := 0 to Num_Threads - 1 do
      Begin
         If (RequerAck) and (Assigned(Threadresultado[Contador])) Then
            Threadresultado[Contador].Encerrar := true;
      End;

      TimerGravacao.Enabled := False;
      TimerOutros.Enabled := False;

      lbl_mensagem.Color := ClRed;

      lbl_mensagem.Caption := 'Aguarde... Encerrando Servi?os';
      TcpSrvForm.Refresh;

      Try
         StopTcpUdpServer;
      Except

         If Srv_Proto = 'tcp' Then
         Begin
            If Assigned(WSocketServer1) Then
               WSocketServer1.Free;
         End
         Else
         Begin
            If Assigned(WSocketUdpRec) Then
               WSocketUdpRec.Free;
         End;

      End;

      Try
         StopThreads;
      Except
      End;

      SalvaLog(Arq_Log, 'Threads Encerradas');

      TimerGravacaoTimer(Sender);

      If Assigned(Recebidos) Then
         Recebidos.Free;
      if Assigned(Conexoes) then
         Conexoes.Free;

      SalvaLog(Arq_Log, 'Servi?o Encerrado com sucesso! ');

      Application.Terminate;

   Except
      Application.Terminate;
   End;
   Action := caFree;
end;

{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
procedure TTcpSrvForm.WSocketUdpRecSessionConnected(Sender: TObject;
   Error: Word);
begin
   if Srv_Equipo = 'SATLIGHT' then
   Begin
   End;
end;

{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
procedure TTcpSrvForm.WSocketServer1ClientConnect(Sender: TObject;
   Client: TWSocketClient; Error: Word);
begin
   if Srv_Equipo = 'ACP245' then
   Begin
      with Client as TTcpSrvClient do
      begin
         LineMode              := False;
         LineEdit              := False;
         MultiThreaded         := False;
         LineLimit             := 1500; { Do not accept long lines }
         OnSocksError          := DoSocksError;
         OnDataAvailable       := ClientDataAvailable_ACP245;
         OnLineLimitExceeded   := ClientLineLimitExceeded;
         OnBgException         := ClientBgException;
         ConnectTime           := Now;
         NumKeepAlive          := 0;
         Id                    := '';
         ConexoesCount.Caption := InttoStr(TWSocketServer(Sender).ClientCount);
      end;
   End
   Else if Srv_Equipo = 'QUANTA_ACP' then
   Begin
      with Client as TTcpSrvClient do
      begin
         LineMode              := False;
         LineEdit              := False;
         MultiThreaded         := False;
         LineLimit             := 1500; { Do not accept long lines }
         OnSocksError          := DoSocksError;
         OnDataAvailable       := ClientDataAvailable_Quanta_Acp;
         OnLineLimitExceeded   := ClientLineLimitExceeded;
         OnBgException         := ClientBgException;
         ConnectTime           := Now;
         NumKeepAlive          := 0;
         Id                    := '';
         ConexoesCount.Caption := InttoStr(TWSocketServer(Sender).ClientCount);
      end;
   End
   Else if Srv_Equipo = 'WEBTECH' then
   Begin
      with Client as TTcpSrvClient do
      begin
         LineMode              := False;
         LineEdit              := False;
         LineLimit             := 1500; { Do not accept long lines }
         OnSocksError          := DoSocksError;
         MultiThreaded         := False;
         OnDataAvailable       := ClientDataAvailable_WEBTECH;
         OnLineLimitExceeded   := ClientLineLimitExceeded;
         OnBgException         := ClientBgException;
         ConnectTime           := Now;
         NumKeepAlive          := 0;
         Id                    := '';
         ConexoesCount.Caption := InttoStr(TWSocketServer(Sender).ClientCount);
      end;
   End
   Else if Srv_Equipo = 'SUNTECH' then
   Begin
      with Client as TTcpSrvClient do
      begin
         LineMode              := False;
         LineEdit              := False;
         LineLimit             := 1500; { Do not accept long lines }
         OnSocksError          := DoSocksError;
         MultiThreaded         := False;
         OnDataAvailable       := ClientDataAvailable_SUNTECH;
         OnLineLimitExceeded   := ClientLineLimitExceeded;
         OnBgException         := ClientBgException;
         ConnectTime           := Now;
         NumKeepAlive          := 0;
         Id                    := '';
         ConexoesCount.Caption := InttoStr(TWSocketServer(Sender).ClientCount);
      end;
   End
   Else if Srv_Equipo = 'QUECLINK' then
   Begin
      with Client as TTcpSrvClient do
      begin
         LineMode              := False;
         LineEdit              := False;
         LineLimit             := 1500; { Do not accept long lines }
         OnSocksError          := DoSocksError;
         MultiThreaded         := False;
         OnDataAvailable       := ClientDataAvailable_QUECLINK;
         OnLineLimitExceeded   := ClientLineLimitExceeded;
         OnBgException         := ClientBgException;
         ConnectTime           := Now;
         NumKeepAlive          := 0;
         Id                    := '';
         ConexoesCount.Caption := InttoStr(TWSocketServer(Sender).ClientCount);
      end;
   End
   Else if Srv_Equipo = 'CALAMP' then
   Begin
      with Client as TTcpSrvClient do
      begin
         LineMode              := False;
         LineEdit              := False;
         LineLimit             := 1500; { Do not accept long lines }
         OnSocksError          := DoSocksError;
         MultiThreaded         := False;
         OnDataAvailable       := ClientDataAvailable_CalAmp;
         OnLineLimitExceeded   := ClientLineLimitExceeded;
         OnBgException         := ClientBgException;
         ConnectTime           := Now;
         NumKeepAlive          := 0;
         Id                    := '';
         ConexoesCount.Caption := InttoStr(TWSocketServer(Sender).ClientCount);
      end;
   End
   Else if Srv_Equipo = 'GENERICO' then
   Begin
      with Client as TTcpSrvClient do
      begin
         LineMode              := False;
         LineEdit              := False;
         LineLimit             := 1500; { Do not accept long lines }
         OnSocksError          := DoSocksError;
         MultiThreaded         := False;
         OnDataAvailable       := ClientDataAvailable_GENERICO;
         OnLineLimitExceeded   := ClientLineLimitExceeded;
         OnBgException         := ClientBgException;
         ConnectTime           := Now;
         NumKeepAlive          := 0;
         Id                    := '';
         ConexoesCount.Caption := InttoStr(TWSocketServer(Sender).ClientCount);
      end;
   End
   Else if Srv_Equipo = 'SATLIGHT' then
   Begin
      with Client as TTcpSrvClient do
      begin
         LineMode              := False;
         LineEdit              := False;
         LineLimit             := 1500; { Do not accept long lines }
         MultiThreaded         := False;
         OnSocksError          := DoSocksError;
         OnDataAvailable       := ClientDataAvailable_SATLIGHT_TCP;
         OnLineLimitExceeded   := ClientLineLimitExceeded;
         OnBgException         := ClientBgException;
         ConnectTime           := Now;
         NumKeepAlive          := 0;
         Id                    := '';
         ConexoesCount.Caption := InttoStr(TWSocketServer(Sender).ClientCount);
      end;
   End;

end;

{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
procedure TTcpSrvForm.WSocketServer1ClientDisconnect(Sender: TObject;
   Client: TWSocketClient; Error: Word);
begin
   with Client as TTcpSrvClient do
   begin

      if Debug in [1, 5, 9] then
         SalvaLog(Arq_Log, 'Cliente desconectou: ' + PeerAddr + ':' + PeerPort +
            ' - Dura??o: ' + FormatDateTime('hh:nn:ss', Now - ConnectTime) +
            ' TCP_Client_Id: ' + InttoStr(Client.CliId));

      ConexoesCount.Caption := InttoStr(TWSocketServer(Sender).ClientCount - 1);

   end;
end;

{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
procedure TTcpSrvForm.WSocketUdpRecSessionClosed(Sender: TObject; Error: Word);
begin

   // ConexoesCount.Caption    := InttoStr( TWSocketServer(Sender).ClientCount -1);

end;

{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
procedure TTcpSrvForm.ClientLineLimitExceeded(Sender: TObject; Cnt: LongInt;
   var ClearData: Boolean);
begin
   with Sender as TTcpSrvClient do
   begin
      SalvaLog(Arq_Log, 'Tamanho de linha excedido:  ' + GetPeerAddr +
         '. Closing.');
      ClearData := true;
      Close;
   end;
end;


{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
Function TTcpSrvForm.EnviaMsgSatLight(var Mensagens: tClientDataSet): Boolean;
// Var Contador  : Integer;
// Client    : TTcpSrvClient;
Begin

   Result := true;
   Try

      Mensagens.First;

      while Not Mensagens.Eof do
      Begin

         MsgPendente.Filtered := False;
         MsgPendente.Filter := 'ID = ' +
            QuotedStr(Mensagens.FieldByName('ID').AsString) +
            ' and  Sequencia = ' + Mensagens.FieldByName('Sequencia').AsString;
         MsgPendente.Filtered := true;
         MsgPendente.First;

         if (MsgPendente.Eof) then
         Begin
            MsgPendente.Append;
            MsgPendente.FieldByName('ID').AsString :=
               Mensagens.FieldByName('ID').AsString;
            MsgPendente.FieldByName('Sequencia').AsString :=
               Mensagens.FieldByName('Sequencia').AsString;
            MsgPendente.FieldByName('Status').AsInteger :=
               Mensagens.FieldByName('Status').AsInteger;;
            MsgPendente.Post
         End
         Else if (MsgPendente.FieldByName('Status').AsInteger = 3) then
         Begin

            Mensagens.Edit;
            Mensagens.FieldByName('Status').AsInteger := 3;
            Mensagens.Post;
            MsgPendente.Delete;

         End;

         Mensagens.Next;

      End;

      MsgPendente.Filtered := False;
      MsgPendente.Filter := 'Status = 3';
      MsgPendente.Filtered := true;
      MsgPendente.First;

      while Not MsgPendente.Eof do
      Begin

         Mensagens.Filtered := False;
         Mensagens.Filter := 'ID = ' + QuotedStr(MsgPendente.FieldByName('ID')
            .AsString) + ' and  Sequencia = ' + MsgPendente.FieldByName
            ('Sequencia').AsString;
         Mensagens.Filtered := true;

         if (Mensagens.Eof) then
         Begin

            Mensagens.Append;
            Mensagens.FieldByName('ID').AsString :=
               MsgPendente.FieldByName('ID').AsString;
            Mensagens.FieldByName('IP_REMOTO').AsString :=
               MsgPendente.FieldByName('IP_REMOTO').AsString;
            Mensagens.FieldByName('PORTA_REMOTO').AsString :=
               MsgPendente.FieldByName('PORTA_REMOTO').AsString;
            Mensagens.FieldByName('Sequencia').AsString :=
               MsgPendente.FieldByName('Sequencia').AsString;
            Mensagens.FieldByName('Mensagem').AsString :=
               MsgPendente.FieldByName('Mensagem').AsString;
            Mensagens.FieldByName('Status').AsString :=
               MsgPendente.FieldByName('Status').AsString;
            Mensagens.Post;

         End
         Else if (Mensagens.FieldByName('Status').AsInteger <>
            MsgPendente.FieldByName('Status').AsInteger) then
         Begin

            Mensagens.Edit;
            Mensagens.FieldByName('Status').AsInteger := 3;
            Mensagens.Post;

         End;

         MsgPendente.Delete;
         MsgPendente.First;

      End;
   Except
      Result := False;
   End;
End;


{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
Function TTcpSrvForm.EnviaMsgAcp245(var Mensagens: tClientDataSet): Boolean;
Var
   Contador: Integer;
   Contador2: Integer;
   Client: TTcpSrvClient;
   // Comando   : String;
   BlobF: TBlobField;
   Stream: TMemoryStream;
   PacketCom: TByteDynArray;
   PacketStr: String;

Begin

   Result := true;

   if Mensagens.RecordCount = 0 then
      Exit;

   For Contador := WSocketServer1.ClientCount - 1 DownTo 0 do
   Begin

      Client := WSocketServer1.Client[Contador] as TTcpSrvClient;

      With Client as TTcpSrvClient do
      Begin

         If Mensagens.Locate('ID', Id, []) then
         Begin
            Try
               If (Debug in [4, 5, 9]) or (Debug_ID = Id) Then
                  SalvaLog(Arq_Log, 'Conectado: (ID/Sequencia): (' +
                     Mensagens.FieldByName('ID').AsString + ':' +
                     Mensagens.FieldByName('Sequencia').AsString + ')');

               Stream := TMemoryStream.Create;
               BlobF := Mensagens.FieldByName('Comando') as TBlobField;
               try
                  BlobF.SaveToStream(Stream);
                  StreamToByteArray(Stream, PacketCom);
                  Stream.Free;
               Except
                  Stream.Free;
               end;

               Client.UltimoAck := UltimoAck;
               Send(PacketCom, Length(PacketCom));
               Mensagens.Edit;
               Mensagens.FieldByName('Status').AsInteger := 3;
               Mensagens.Post;
               NumMens := NumMens + 1;
               MsgSequencia := Mensagens.FieldByName('Sequencia').AsInteger;
               Result := true;

               PacketStr := '';

               for Contador2 := 0 to Length(PacketCom) - 1 do
                  PacketStr := PacketStr +
                     IntToHex(PacketCom[Contador2], 2) + '';

               If (Debug in [4, 5, 9]) or (Debug_ID = Id) Then
                  SalvaLog(Arq_Log, 'Mensagem Enviada: (ID/Sequencia): (' +
                     Mensagens.FieldByName('ID').AsString + ':' +
                     Mensagens.FieldByName('Sequencia').AsString + ') ' +
                     PacketStr);

            Except

               If Debug in [4, 5, 9] Then
                  SalvaLog(Arq_Log, 'Erro ao Enviar Mensagem: (ID/Sequencia): ('
                     + Mensagens.FieldByName('ID').AsString + ':' +
                     Mensagens.FieldByName('Sequencia').AsString + ')');
               Result := False;
               Close;
            End;

         End;
      End;

   End;
End;
{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
Function TTcpSrvForm.EnviaMsgQuanta_Acp(var Mensagens: tClientDataSet): Boolean;
Var
   Contador: Integer;
   Contador2: Integer;
   Client: TTcpSrvClient;
   // Comando   : String;
   BlobF: TBlobField;
   Stream: TMemoryStream;
   PacketCom: TByteDynArray;
   PacketStr: String;

Begin

   Result := true;

   if Mensagens.RecordCount = 0 then
      Exit;

   For Contador := WSocketServer1.ClientCount - 1 DownTo 0 do
   Begin

      Client := WSocketServer1.Client[Contador] as TTcpSrvClient;

      With Client as TTcpSrvClient do
      Begin

         If Mensagens.Locate('ID', Id, []) then
         Begin
            Try
               If (Debug in [4, 5, 9]) or (Debug_ID = Id) Then
                  SalvaLog(Arq_Log, 'Conectado: (ID/Sequencia): (' +
                     Mensagens.FieldByName('ID').AsString + ':' +
                     Mensagens.FieldByName('Sequencia').AsString + ')');

               Stream := TMemoryStream.Create;
               BlobF := Mensagens.FieldByName('Comando') as TBlobField;
               try
                  BlobF.SaveToStream(Stream);
                  StreamToByteArray(Stream, PacketCom);
                  Stream.Free;
               Except
                  Stream.Free;
               end;

               Client.UltimoAck := UltimoAck;
               Send(PacketCom, Length(PacketCom));
               Mensagens.Edit;
               Mensagens.FieldByName('Status').AsInteger := 3;
               Mensagens.Post;
               NumMens := NumMens + 1;
               MsgSequencia := Mensagens.FieldByName('Sequencia').AsInteger;
               Result := true;

               PacketStr := '';

               for Contador2 := 0 to Length(PacketCom) - 1 do
                  PacketStr := PacketStr +
                     IntToHex(PacketCom[Contador2], 2) + '';

               If (Debug in [4, 5, 9]) or (Debug_ID = Id) Then
                  SalvaLog(Arq_Log, 'Mensagem Enviada: (ID/Sequencia): (' +
                     Mensagens.FieldByName('ID').AsString + ':' +
                     Mensagens.FieldByName('Sequencia').AsString + ') ' +
                     PacketStr);

            Except

               If Debug in [4, 5, 9] Then
                  SalvaLog(Arq_Log, 'Erro ao Enviar Mensagem: (ID/Sequencia): ('
                     + Mensagens.FieldByName('ID').AsString + ':' +
                     Mensagens.FieldByName('Sequencia').AsString + ')');
               Result := False;
               Close;
            End;

         End;
      End;

   End;
End;

{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
procedure TTcpSrvForm.RecebeResultado(pId: String; pClient: Integer;
   pIP, pPorta: String; pResposta: TStream);
Var
   Contador: Integer;
   Contador2: Word;
   Client: TTcpSrvClient;
   Msg: String;
   PacketRes: TByteDynArray;
Begin

   if (Srv_Equipo = 'ACP245') or (Srv_Equipo = 'QUANTA_ACP') then
   Begin

      pResposta.Position := 0;

      StreamToByteArray(pResposta, PacketRes);

      For Contador := WSocketServer1.ClientCount - 1 downto 0 do
      Begin

         Client := WSocketServer1.Client[Contador] as TTcpSrvClient;

         With Client as TTcpSrvClient do
         Begin
            if (CliId = pClient) and (Id = '') then
               Id := pId;

            if (CliId = pClient) and (Length(PacketRes) > 0) then
            Begin

               Send(PacketRes, Length(PacketRes));
               Client.Flush;

               If (Debug in [5, 9]) or (Debug_ID = Id) Then
               Begin
                  if Length(PacketRes) > 0 then
                  Begin
                     Msg := '';
                     for Contador2 := 0 to Length(PacketRes) - 1 do
                        Msg := Msg + InttoStr(PacketRes[Contador2]) + ':';
                  End;
                  SalvaLog(Arq_Log, 'Ack Enviado: (ID): (' + Id + '): ' + Msg);
               End;

               Exit;

            End

         End;

      End;
   End;

End;

{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }

{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
procedure TTcpSrvForm.ClientDataAvailable_ACP245(Sender: TObject; Error: Word);
Var
   BytesTot: Integer;
   BlobF: TBlobField;
   BufferRec: TStream;
   Contador: Word;
   PackAnterior: String;
   KeepAliveRes: TByteDynArray;

begin

   with Sender as TTcpSrvClient do
   begin

      if Error <> 0 then
      Begin
         SalvaLog(Arq_Log, 'Erro: ' + InttoStr(Error) + WSocketErrorDesc(Error)
            + ' - ' + GetPeerAddr + ':' + GetPeerPort);
         Exit;
      End;

      BytesTot := Receive(@PacketRec, Sizeof(PacketRec));

      if BytesTot <= 0 then
         Exit;

      Inc(NumpackRec);
      Inc(NumPackEst);
      NumRecebido := NumRecebido + 1;
      UltMensagem := Now;

      // Ack {11:4:32:4};
      if (BytesTot = 4) and (PacketRec[0] = 11) and (PacketRec[1] = 4) then
      Begin
         SetLength(KeepAliveRes, 4);
         // 1 Byte Application ID
         KeepAliveRes[0] := 11;
         // 2 Byte MessageType = 5 = Keep Alive Reply
         KeepAliveRes[1] := 5;
         // 3 Byte Application Version  + Message Control Flag
         KeepAliveRes[2] := PacketRec[2];
         // 4 Byte Message length
         KeepAliveRes[3] := 4;
         Send(KeepAliveRes, Length(KeepAliveRes));
         Duplicado := 0;
         NumKeepAlive := NumKeepAlive + 1;

         Exit;
      End;

      Duplicado := 0;
      PackAnterior := RcvdPacket;
      RcvdPacket := '';

      for Contador := 0 to BytesTot - 1 do
         RcvdPacket := RcvdPacket + IntToHex(PacketRec[Contador], 2) + ':';

      if (PackAnterior = RcvdPacket) and (Length(RcvdPacket) >= 20) and
         (Length(PackAnterior) >= 20) then
         Duplicado := 1
      Else
         Duplicado := 0;

      if (Debug in [1, 5, 9]) or (Debug_ID = Id) then
         SalvaLog(Arq_Log, 'Recebido: ' + RcvdPacket);

      while Recebidos.ReadOnly do
      Begin
         Sleep(1);
         SalvaLog(Arq_Log, 'Aguardando Destravar Arquivo Recebido: ');
      End;

      Begin

         Recebidos.Append;
         Recebidos.FieldByName('IP').AsString := GetPeerAddr;
         Recebidos.FieldByName('ID').AsString := Id;
         Recebidos.FieldByName('Porta').AsString := GetPeerPort;
         Recebidos.FieldByName('TCP_CLIENT').AsInteger := CliId;
         Recebidos.FieldByName('Processado').AsBoolean := False;
         Recebidos.FieldByName('MsgSequencia').AsInteger := MsgSequencia;
         Recebidos.FieldByName('Duplicado').AsInteger := Duplicado;
         Recebidos.FieldByName('Data_rec').AsDateTime := Now;

         BlobF := Recebidos.FieldByName('DataGrama') as TBlobField;

         Try
            BufferRec := Recebidos.CreateBlobStream(BlobF, bmWrite);
            try
               BufferRec.Write(PacketRec, BytesTot);
            finally
               BufferRec.Free;
            end;
         Except
            SalvaLog(Arq_Log, 'Erro ao Criar o TBlobField: ');
         End;

         Recebidos.Post;

      End;

      pacotes.Caption := InttoStr(NumpackRec);
      PacotesSeg.Caption := FormatFloat('##0',
         NumpackRec / ((Now - ServerReStartUp) * 24 * 60 * 60));
      // Atualiza pacotes recebidos / mensagens Enviadas deste cliente

   end;

end;
{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
procedure TTcpSrvForm.ClientDataAvailable_Quanta_Acp(Sender: TObject; Error: Word);
Var
   BytesTot: Integer;
   BlobF: TBlobField;
   BufferRec: TStream;
   Contador: Word;
   PackAnterior: String;
   KeepAliveRes: TByteDynArray;

begin

   with Sender as TTcpSrvClient do
   begin

      if Error <> 0 then
      Begin
         SalvaLog(Arq_Log, 'Erro: ' + InttoStr(Error) + WSocketErrorDesc(Error)
            + ' - ' + GetPeerAddr + ':' + GetPeerPort);
         Exit;
      End;

      BytesTot := Receive(@PacketRec, Sizeof(PacketRec));

      if BytesTot <= 0 then
         Exit;

      Inc(NumpackRec);
      Inc(NumPackEst);
      NumRecebido := NumRecebido + 1;
      UltMensagem := Now;

      // Ack {11:4:32:4};
      if (BytesTot = 4) and (PacketRec[0] = 11) and (PacketRec[1] = 4) then
      Begin
         SetLength(KeepAliveRes, 4);
         // 1 Byte Application ID
         KeepAliveRes[0] := 11;
         // 2 Byte MessageType = 5 = Keep Alive Reply
         KeepAliveRes[1] := 5;
         // 3 Byte Application Version  + Message Control Flag
         KeepAliveRes[2] := PacketRec[2];
         // 4 Byte Message length
         KeepAliveRes[3] := 4;
         Send(KeepAliveRes, Length(KeepAliveRes));
         Duplicado := 0;
         NumKeepAlive := NumKeepAlive + 1;

         Exit;
      End;

      Duplicado := 0;
      PackAnterior := RcvdPacket;
      RcvdPacket := '';

      for Contador := 0 to BytesTot - 1 do
         RcvdPacket := RcvdPacket + IntToHex(PacketRec[Contador], 2) + ':';

      if (PackAnterior = RcvdPacket) and (Length(RcvdPacket) >= 20) and
         (Length(PackAnterior) >= 20) then
         Duplicado := 1
      Else
         Duplicado := 0;

      if (Debug in [1, 5, 9]) or (Debug_ID = Id) then
         SalvaLog(Arq_Log, 'Recebido: ' + RcvdPacket);

      while Recebidos.ReadOnly do
      Begin
         Sleep(1);
         SalvaLog(Arq_Log, 'Aguardando Destravar Arquivo Recebido: ');
      End;

      Begin

         Recebidos.Append;
         Recebidos.FieldByName('IP').AsString := GetPeerAddr;
         Recebidos.FieldByName('ID').AsString := Id;
         Recebidos.FieldByName('Porta').AsString := GetPeerPort;
         Recebidos.FieldByName('TCP_CLIENT').AsInteger := CliId;
         Recebidos.FieldByName('Processado').AsBoolean := False;
         Recebidos.FieldByName('MsgSequencia').AsInteger := MsgSequencia;
         Recebidos.FieldByName('Duplicado').AsInteger := Duplicado;

         BlobF := Recebidos.FieldByName('DataGrama') as TBlobField;

         Try
            BufferRec := Recebidos.CreateBlobStream(BlobF, bmWrite);
            try
               BufferRec.Write(PacketRec, BytesTot);
            finally
               BufferRec.Free;
            end;
         Except
            SalvaLog(Arq_Log, 'Erro ao Criar o TBlobField: ');
         End;

         Recebidos.Post;

      End;

      pacotes.Caption := InttoStr(NumpackRec);
      PacotesSeg.Caption := FormatFloat('##0',
         NumpackRec / ((Now - ServerReStartUp) * 24 * 60 * 60));
      // Atualiza pacotes recebidos / mensagens Enviadas deste cliente

   end;

end;

{ SATLIGHT }
{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
procedure TTcpSrvForm.ClientDataAvailable_SATLIGHT_TCP(Sender: TObject;
   Error: Word);
Var
   Contador: Integer;
   BytesTot: Integer;
   BlobF: TBlobField;
   BufferRec: TStream;
begin

   // TCP
   if Srv_Proto = 'tcp' then
      with Sender as TTcpSrvClient do
      begin

         if Error <> 0 then
         Begin
            SalvaLog(Arq_Log, 'Erro: ' + InttoStr(Error) +
               WSocketErrorDesc(Error) + ' - ' + GetPeerAddr + ':' +
               GetPeerPort);
            Exit;
         End;

         BytesTot := Receive(@PacketRec, Sizeof(PacketRec));

         if BytesTot <= 0 then
            Exit;

         RcvdPacket := '';

         for Contador := 0 to BytesTot - 1 do
            RcvdPacket := RcvdPacket + InttoStr(Ord(PacketRec[Contador])) + ':';

         if (Debug in [1, 5, 9]) or (Debug_ID = Id) then
            SalvaLog(Arq_Log, 'Recebido: ' + RcvdPacket);

         while Recebidos.ReadOnly do
         Begin
            Sleep(1);
            SalvaLog(Arq_Log, 'Aguardando Destravar Arquivo Recebido: ');
         End;

         Begin

            Recebidos.Append;
            Recebidos.FieldByName('IP').AsString := GetPeerAddr;
            Recebidos.FieldByName('ID').AsString := Id;
            Recebidos.FieldByName('Porta').AsString := GetPeerPort;
            Recebidos.FieldByName('TCP_CLIENT').AsInteger := CliId;
            Recebidos.FieldByName('Processado').AsBoolean := False;
            Recebidos.FieldByName('MsgSequencia').AsInteger := MsgSequencia;
            BlobF := Recebidos.FieldByName('DataGrama') as TBlobField;

            Try
               BufferRec := Recebidos.CreateBlobStream(BlobF, bmWrite);
               try
                  BufferRec.Write(PacketRec, BytesTot);
               finally
                  BufferRec.Free;
               end;
            Except
               SalvaLog(Arq_Log, 'Erro ao Criar o TBlobField: ');
            End;

            Recebidos.Post;

         End;

         Inc(NumpackRec);
         Inc(NumPackEst);
         pacotes.Caption := InttoStr(NumpackRec);
         PacotesSeg.Caption := FormatFloat('##0',
            NumpackRec / ((Now - ServerReStartUp) * 24 * 60 * 60));

         // Atualiza pacotes recebidos / mensagens Enviadas deste cliente
         NumRecebido := NumRecebido + 1;
         UltMensagem := Now;

      end;

end;
{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
{ GERAL UDP }

procedure TTcpSrvForm.WSocketUdpRecDataAvailable(Sender: TObject; Error: Word);
Begin

   if Srv_Equipo = 'SATLIGHT' then
      DataAvailable_Satlight(Sender,Error)
   Else if Srv_Equipo = 'QUANTA' then
      DataAvailable_Quanta( Sender,Error);

End;


{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
{ SATLIGHT UDP }
procedure TTcpSrvForm.DataAvailable_Satlight(Sender: TObject; Error: Word);
var
   Src: TSockAddrIn;
   SrcLen: Integer;
   BufferOut: Array [0 .. 1023] of Byte;
   BytesTot: Integer;
   Contador: Integer;
   BlobF: TBlobField;
   BufferRec: TStream;
   RcvdPacket: String;
   ip, porta: String;
   AckEnvio: Word;
   Serial: String;
   Comando: String;
Begin
   Begin

      Serial := '';
      SrcLen := Sizeof(TSockAddrIn);
      BytesTot := WSocketUdpRec.ReceiveFrom(@PacketRec, Sizeof(PacketRec),Src, SrcLen);

      Try

         ip    := String(WSocket_inet_ntoa(Src.sin_addr));
         porta := IntToStr(WSocket_ntohs(Src.sin_port));


         for Contador := 0 to BytesTot - 1 do
            RcvdPacket := RcvdPacket + IntToHex(PacketRec[Contador], 2) + ':';

         if (PacketRec[0] = $FF) or (PacketRec[0] = $FE) then
         Begin

            Serial := IntToHex(PacketRec[2], 2) + IntToHex(PacketRec[3], 2) +
               IntToHex(PacketRec[4], 2) + IntToHex(PacketRec[5], 2);

            Try
               AckEnvio := StrTointDef('$3B' + IntToHex(PacketRec[6], 2),0);
               WSocketUdpRec.SendTo(Src, SrcLen, @AckEnvio, Sizeof(AckEnvio));
               if (Debug in [5, 9]) then
                  SalvaLog(Arq_Log, 'Ack Enviado - IP: ' + ip + ' Porta: ' +
                     porta + ' Ack: ' + IntToHex(AckEnvio, 4));
            Except

               SalvaLog(Arq_Log, 'Erro ao Enviar via Sendto: ' +
                  IntToHex(AckEnvio, 4));

            End;

         End
         Else if (PacketRec[0] = $30) then
         Begin
            Serial := Chr(PacketRec[4]) + Chr(PacketRec[5]) + Chr(PacketRec[6])
                    + Chr(PacketRec[7]) + Chr(PacketRec[8]) + Chr(PacketRec[9])
                    + Chr(PacketRec[10]) + Chr(PacketRec[11]);
         End
         Else
            Serial := '';

         if Debug in [5, 9] then
         Begin
            SalvaLog(Arq_Log, 'Recebido: ' + 'IP: ' + ip + ' -  Porta: ' + porta
               + ' - ' + 'Serial: ' + Serial + ':' + Chr(13) +
               InttoStr(BytesTot) + ' Bytes: ' + RcvdPacket);
         End;

         if Serial <> '' then
            Try

               MsgPendente.Filtered := False;
               MsgPendente.Filter := 'id = ' + QuotedStr(Serial) +
                  ' and Status <> 3';
               MsgPendente.Filtered := true;
               MsgPendente.First;

               while (Not MsgPendente.Eof) do
               Begin

                  Comando := MsgPendente.FieldByName('Mensagem').AsString;

                  for Contador := 0 to Length(Comando) - 1 do
                     BufferOut[Contador] := Ord(Comando[Contador + 1]);

                  WSocketUdpRec.SendTo(Src, Sizeof(Src), @BufferOut,
                     Length(Comando));

                  MsgPendente.Edit;
                  MsgPendente.FieldByName('Status').AsInteger := 3;
                  MsgPendente.Post;

                  If (Debug in [4, 5, 9]) or (Debug_ID = Serial) Then
                     SalvaLog(Arq_Log, 'Mensagem Enviada:  (' + Comando + ')');

                  MsgPendente.Next;

               End;

            Except
               on E: Exception do
                  SalvaLog(Arq_Log, 'Erro ao Enviar a Mensagem: ' + E.Message);
            End;

      Except
         SalvaLog(Arq_Log, 'Erro depois de receber o pacote');
      End;

      if BytesTot >= 0 then
      begin

         // WSocketUdpRec.SendStr(Char(1) + Char(2));

         // no udp ? usado tambem como contador
         Inc(NumpackRec);
         Inc(NumPackEst);

         Begin

            Recebidos.Append;
            Recebidos.FieldByName('IP').AsString            := ip;
            Recebidos.FieldByName('Porta').AsString         := porta;
            Recebidos.FieldByName('Processado').AsBoolean   := False;
            Recebidos.FieldByName('MsgSequencia').AsInteger := NumpackRec;
            BlobF := Recebidos.FieldByName('DataGrama') as TBlobField;

            Try
               BufferRec := Recebidos.CreateBlobStream(BlobF, bmWrite);
               try
                  BufferRec.Write(PacketRec, BytesTot);
               finally
                  BufferRec.Free;
               end;
            Except
               SalvaLog(Arq_Log, 'Erro ao Criar o TBlobField: ');
            End;

            Recebidos.Post;

         End;

         pacotes.Caption := InttoStr(NumpackRec);
         PacotesSeg.Caption := FormatFloat('##0',
            NumpackRec / ((Now - ServerReStartUp) * 24 * 60 * 60));

         {
           DataAvailableLabel.Caption := IntToStr(atoi(DataAvailableLabel.caption) + 1) +
           '  ' + String(StrPas(inet_ntoa(Src.sin_addr))) +
           ':'  + IntToStr(ntohs(Src.sin_port)) +
           '--> ' + String(StrPas(Buffer));
         }

      end;
   end;
end;

{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
{ Quanta UDP }
procedure TTcpSrvForm.DataAvailable_Quanta(Sender: TObject; Error: Word);
var
   Src: TSockAddrIn;
   SrcLen: Integer;
   BytesRec: Integer;
   BytesEnv: Integer;
   Contador: Integer;
   BufferRec: TStream;
   RcvdPacket: String;
   ip, porta: String;
   AckEnvio: Array [0 .. 15] of Byte;
   CmdEnvio: Array of Byte;
   EnviarAck: Boolean;
   Serial: String;
   Comando: String;
   SequenciaRec: Word;
   SequenciaEnv: Word;
   ByteContador: Word;
   ByteStr: String;
   Tipo: Byte;
   Produto: Byte;
   Versao: Byte;
   CRCCalc: Word;
   CRCRec: Word;
   CRCAck: Word;
   Tamanho: Word;
   Erros: Byte;
   CodErro: Byte;
//   NovaSequencia: Boolean;
   QuantaDupl: Integer;
   BlobF: TBlobField;
   Stream: TMemoryStream;
   PacketCom: TByteDynArray;


Begin
   Try

      Serial   := '';
      SrcLen   := Sizeof(TSockAddrIn);
      BytesRec := WSocketUdpRec.ReceiveFrom(@PacketRec, Sizeof(PacketRec),Src, SrcLen);
      Erros    := 0;

      Try

         ip    := String(WSocket_inet_ntoa(Src.sin_addr));
         porta := IntToStr(WSocket_ntohs(Src.sin_port));
          // no udp ? usado tambem como contador
         Inc(NumpackRec);
         Inc(NumPackEst);

         for Contador  := 0 to BytesRec - 1 do
            RcvdPacket := RcvdPacket + IntToHex(PacketRec[Contador], 2) + ':';

         try

            if BytesRec >= 16 then
            Begin
               Produto      := PacketRec[0];
               Versao       := PacketRec[1];
               Tipo         := PacketRec[11];
               Serial       := Trim(FormatFloat('##########00',StrtoIntDef('$' + InttoHex(PacketRec[2],2) + InttoHex(PacketRec[3],2) + InttoHex(PacketRec[4],2) + InttoHex(PacketRec[5],2),0)));
               Tamanho      := (PacketRec[12] * 256) + PacketRec[13];
               SequenciaRec := PacketRec[6];
               CRCRec       := (PacketRec[BytesRec-2]*256) + PacketRec[BytesRec-1];
               CRCCalc      := crc16_ccitt(PacketRec, $1021, $ffff, BytesRec-2);
               CodErro      := PacketRec[14];
            End
            Else
            Begin
               Produto      := 0;
               Versao       := 0;
               Tipo         := 0;
               Serial       := '';
               Tamanho      := 0;
               SequenciaRec := 0;
               CRCRec       := 0;
               CRCCalc      := 0;
               Erros        := 1;
               CodErro      := 0;
            End;
         except
            SalvaLog(Arq_Log, 'Erro ao ler o Header: Serial: ' + Serial + ' - CRCREC: ' + InttoStr(CRCRec)  + ' - CRCCalc: ' + InttoStr(CRCCalc));
         end;

         EnviarAck := True;

         //Primeiro Algumas valida??es:
         //Tamanho minino Header + CRC
         if BytesRec = -1 Then
         Begin
            EnviarAck    := False; //Nao Envia Ack
            Erros        := 1;  //N?o Salva
         End
         //Keep alive -- Ignora
         Else if (Tipo = $11) then
         Begin
            EnviarAck    := False; //Nao Envia Ack
            Erros        := 1;     //Nao ? considerado erro grava ip/porta    //N?o Salva
         End
         Else if (BytesRec > 0 ) and (BytesRec < 16) Then
         Begin
            SalvaLog(Arq_Log, 'Quanta Recebido - Header Inv?lido: ' + 'IP: ' + ip + ' -  Porta: ' + porta
               + ' - ' + 'Serial: ' + Serial + ':' + Chr(13) +
               InttoStr(BytesRec) + ' Bytes: ' + RcvdPacket );

            EnviarAck    := False;
            Erros        := 2; //Salva
         End
         //Erro no Produto 0x31 patote 0x11 - Tabela de estado
         Else If (Produto = $31) and (Tipo in [$4C,$4D]) and (BytesRec < 40) then
         Begin
            SalvaLog(Arq_Log, 'Quanta Recebido - Produto 0x31 - Tipo 0x4C ou 0x4D: ' + 'IP: ' + ip + ' -  Porta: ' + porta
               + ' - ' + 'Serial: ' + Serial + ':' + Chr(13) +
               'Recebido: ' + RcvdPacket);

            Erros        := 3;  //Salva
            EnviarAck    := False; //Nao Envia Ack
         End
         //Erro no Produto 0x99 patote + Tabela de estado
         Else If (Produto <> $31) and  (Tipo in [$0D,$0E,$07,$12,$13])  and (BytesRec < 40) then
         Begin
            SalvaLog(Arq_Log, 'Quanta Recebido - Produto 0x99 - Tipo Estado: ' + 'IP: ' + ip + ' -  Porta: ' + porta
               + ' - ' + 'Serial: ' + Serial + ':' + Chr(13) +
               'Recebido: ' + RcvdPacket);

            Erros        := 4;   //Salva
            EnviarAck    := False; //Nao Envia Ack
         End
         //Diferen?a no tamanho Recebido com o Informado
         Else If (Tamanho <> BytesRec) and (Tipo <> $11) then
         Begin
            SalvaLog(Arq_Log, 'Quanta Recebido - Tamanho Inv?lido: ' + 'IP: ' + ip + ' -  Porta: ' + porta
               + ' - ' + 'Serial: ' + Serial + ':' + Chr(13) +
               'Recebido: ' + InttoStr(BytesRec) + ' - Informado: ' + InttoStr(Tamanho) + ' : '+ RcvdPacket);

            Erros        := 5;  //Salva
            EnviarAck    := False;
         End
         //Erro de CRC
         Else if CRCRec <>  CRCCalc then
         Begin
            SalvaLog(Arq_Log, 'Quanta Recebido - CRC Inv?lido: ' + 'IP: ' + ip + ' -  Porta: ' + porta
               + ' - ' + 'Serial: ' + Serial + ':' + Chr(13) +
               InttoStr(BytesRec) + ' Bytes: ' + RcvdPacket +
               'Recebido: ' + InttoStr(CRCRec) + ' - Calculado: ' + InttoStr(CRCCalc));

            Erros        := 6;  //Salva
            EnviarAck    := False; //Nao Envia Ack
         End;

         //Erro de sequencia - Ignorar
         If (tipo in [$05]) then
         Begin
            EnviarAck := False;
            Erros        := 7;  //Salva
            If (BytesRec = 20) and (CodErro = 1) Then
            Begin
               SequenciaEnv  := PacketRec[17];
//               NovaSequencia := True;
               Erros         := 1;  //N?o Salva
            End;
            // 400C0000A5836550B50CFA050014010565018F0A
         End;

         if (Debug_ID = Serial) and (BytesRec >=16) then
            SalvaLog(Arq_Log, 'Quanta Recebido: ' + 'IP: ' + ip + ' -  Porta: ' + porta
               + ' - ' + 'Serial: ' + Serial + ':' + Chr(13) +
               InttoStr(BytesRec) + ' Bytes - Erros:' + InttoStr(Erros) + ' : ' + RcvdPacket);

      Except
         SalvaLog(Arq_Log, 'Erro depois de receber o pacote:' + InttoStr(Erros));
      End;

//      NovaSequencia := False;

      if (Debug_ID = Serial) or (Debug in [5, 9]) then
      Begin
         if EnviarAck  then
            SalvaLog(Arq_Log, 'EnviarAck: Serial : Erros : ' + Serial + ' : ' + InttoStr(Erros) )
         Else
            SalvaLog(Arq_Log, 'NAO EnviarAck: Serial : Erros : ' + Serial + ' : ' + InttoStr(Erros) )


      End;

      //Se o serial for v?lido, Checa por resposta pendente
      Try

         MsgPendente.Filtered := False;
         MsgPendente.Filter   := 'id = ' + QuotedStr(Serial) +
            ' and Status <> 3';
         MsgPendente.Filtered := true;
         MsgPendente.First;

         while (Not MsgPendente.Eof) do
         Begin

            MsgPendente.FieldByName('Comando').AsString;

            Comando := '';

            for Contador  := 1 to Trunc((Length(MsgPendente.FieldByName('Comando').AsString)/2)) do
            Begin
               ByteStr              := Copy(MsgPendente.FieldByName('Comando').AsString,(((Contador-1)*2)+1), 2);
               ByteContador         := StrtoInt('$'+ByteStr);
               Comando              := Comando + ByteStr + ':';
               SetLength(CmdEnvio,Contador);
               CmdEnvio[Contador-1] := ByteContador;
               BytesEnv             := Contador;
            End;

            If WSocketUdpRec.SendTo(Src, Sizeof(Src), @CmdEnvio, Length(CmdEnvio)) = BytesEnv Then
            Begin
               MsgPendente.Edit;
               MsgPendente.FieldByName('Status').AsInteger := 3;
               MsgPendente.Post;
               EnviarAck := False;
            End
            Else
               SalvaLog(Arq_Log, 'Diferen?a de Bytes enviados: ' + Serial + ' / ' + '(' + Comando + ')' + ' Tamanho CMD: '+ InttoStr(BytesEnv));

            If (Debug in [4, 5, 9]) or (Debug_ID = Serial) Then
               SalvaLog(Arq_Log, 'ID/Comando Enviado - Sem ACK: ' + Serial + ' / ' + '(' + Comando + ')' + ' Tamanho CMD: '+ InttoStr(BytesEnv));

            MsgPendente.Next;

         End;

      Except
         on E: Exception do
            SalvaLog(Arq_Log, 'Erro ao Enviar a Mensagem: ' + E.Message);
      End;

      //Se foi enviado comando / mensagem o ack n?o ? mais necess?rio
      if EnviarAck then
      Try
         Begin

            Comando := '';

            //Monta o Ack
            for Contador := 0 to 15 do
               AckEnvio[Contador] := PacketRec[Contador];

            AckEnvio[07]          := 0; //Zera TimeStamp
            AckEnvio[08]          := 0; //Zera TimeStamp
            AckEnvio[09]          := 0; //Zera TimeStamp
            AckEnvio[10]          := 0; //Zera TimeStamp

            // O Ack ? uma mensagem do tipo +/- $50
            If AckEnvio[11] < $50 then
               AckEnvio[11]       := AckEnvio[11] + $50
            else
               AckEnvio[11]       := AckEnvio[11] - $50;

            AckEnvio[12]          := 0; //Novo Tamanho
            AckEnvio[13]          := 16; //Novo Tamanho
            CRCAck                := crc16_ccitt(AckEnvio, $1021, $ffff,14);
            AckEnvio[14]          := StrtoIntDef('$' + Copy(InttoHex(CRCAck,4),1,2),0);
            AckEnvio[15]          := StrtoIntDef('$' + Copy(InttoHex(CRCAck,4),3,2),0);

            WSocketUdpRec.SendTo(Src, SrcLen, @AckEnvio, Length(AckEnvio));

            if (Debug_ID = Serial) or (Debug in [5, 9]) then
            Begin
               for Contador  := 0 to Length(AckEnvio) - 1 do
                  Comando := Comando + IntToHex(AckEnvio[Contador], 2) + ':';
               SalvaLog(Arq_Log, 'Ack Enviado - IP: ' + ip + ' Porta: ' + porta + ' - ' + ' - ' + 'Serial: ' + Serial + ':' + Chr(13) + Comando );
            End;

         End;
      Except
         SalvaLog(Arq_Log, 'Erro ao Gerar/Enviar Ack - IP: ' + ip + ' Porta: ' + porta + ' - ' + Comando );
      End;


      {Grava o pacote para decodificar e salvar no banco}
      If Erros <= 0 then
      begin

         QuantaDupl := 0;

         If QuantaRec.FindKey([Serial]) and (serial <> '')  Then
         Begin
            if QuantaRec.FieldByName('DataGrama').AsString =  RcvdPacket Then
               QuantaDupl := 1;
         End;

         if QuantaDupl <= 0 then
         Begin

            Recebidos.Append;
            Recebidos.FieldByName('ID').AsString            := Serial;
            Recebidos.FieldByName('IP').AsString            := ip;
            Recebidos.FieldByName('Porta').AsString         := porta;
            Recebidos.FieldByName('MsgSequencia').AsInteger := SequenciaRec;
            Recebidos.FieldByName('Produto').AsInteger      := Produto;
            Recebidos.FieldByName('Versao').AsInteger       := Versao;
            Recebidos.FieldByName('Tipo').AsInteger         := Tipo;
            Recebidos.FieldByName('Duplicado').AsInteger    := QuantaDupl;

            BlobF := Recebidos.FieldByName('DataGrama') as TBlobField;

            Try
               BufferRec := Recebidos.CreateBlobStream(BlobF, bmWrite);
               try
                  BufferRec.Write(PacketRec, BytesRec);
               finally
                  BufferRec.Free;
               end;
            Except
               SalvaLog(Arq_Log, 'Erro ao Criar o TBlobField: ');
            End;

            Recebidos.Post;
         End;

         pacotes.Caption    := InttoStr(NumpackRec);
         PacotesSeg.Caption := FormatFloat('##0', NumpackRec / ((Now - ServerReStartUp) * 24 * 60 * 60));

      end
      Else If Erros > 1 then
      Try
      Begin

         Recebidos.Append;
         Recebidos.FieldByName('ID').AsString            := Serial;
         Recebidos.FieldByName('IP').AsString            := ip;
         Recebidos.FieldByName('Porta').AsString         := porta;
         Recebidos.FieldByName('MsgSequencia').AsInteger := SequenciaRec;
         Recebidos.FieldByName('Produto').AsInteger      := Produto;
         Recebidos.FieldByName('Versao').AsInteger       := Versao;
         Recebidos.FieldByName('Tipo').AsInteger         := Tipo;
         Recebidos.FieldByName('Duplicado').AsInteger    := QuantaDupl;
         Recebidos.FieldByName('Coderro').AsInteger      := Erros;

         BlobF := Recebidos.FieldByName('DataGrama') as TBlobField;

         Try
            BufferRec := Recebidos.CreateBlobStream(BlobF, bmWrite);
            try
               BufferRec.Write(PacketRec, BytesRec);
            finally
               BufferRec.Free;
            end;
         Except
            SalvaLog(Arq_Log, 'Erro ao Criar o TBlobField: ');
         End;

         Recebidos.Post;

      End;
      Except
         SalvaLog(Arq_Log, 'Erro ao Salvar pacote recebido para decoder: ');
      End;
      // Salva ou atualiza para fins de IP / PORTA

      If QuantaRec.FindKey([Serial]) Then
         QuantaRec.Edit
      Else
         QuantaRec.Append;

      QuantaRec.FieldByName('ID').AsString            := Serial;
      QuantaRec.FieldByName('SeqRecebe').AsInteger    := SequenciaRec;
      QuantaRec.FieldByName('SeqEnvio').AsInteger     := SequenciaEnv;
      QuantaRec.FieldByName('Produto').AsInteger      := Produto;
      QuantaRec.FieldByName('Tipo').AsInteger         := Tipo;
      QuantaRec.FieldByName('Versao').AsInteger       := Versao;
      QuantaRec.FieldByName('Duplicado').Asinteger    := QuantaDupl;
      QuantaRec.FieldByName('IP').Asstring            := ip;
      QuantaRec.FieldByName('Porta').Asstring         := porta;

      if erros = 0  then
         QuantaRec.FieldByName('DataGrama').AsString     := RcvdPacket;

      QuantaRec.Post;

   Except
      SalvaLog(Arq_Log, 'Erro na procedure DataAvailable_Quanta');
   End;

end;

{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
Function TTcpSrvForm.EnviaMsgQuanta(var Mensagens: tClientDataSet): Boolean;
Var
   Msgporta          : Word;
   Tamanho           : Word;
   Contador          : integer;
   Resultado         : Integer;
   Comando           : String;
   Serial            : String;
   MsgIP             : WideString;
   PacketEnv         : tBytes;
Begin

   Result := true;
   Try

      Mensagens.First;

      while Not Mensagens.Eof do
      Begin

         if (Mensagens.FieldByName('ID').AsString = Debug_id) then
            SalvaLog(Arq_Log, 'Transfer?ncia de Comandos: ' + QuotedStr(Mensagens.FieldByName('ID').AsString) + ' / ' + Mensagens.FieldByName('Sequencia').AsString);

         MsgPendente.Filtered := False;
         MsgPendente.Filter := 'ID = ' +
            QuotedStr(Mensagens.FieldByName('ID').AsString) +
            ' and  Sequencia = ' + Mensagens.FieldByName('Sequencia').AsString;
         MsgPendente.Filtered := true;
         MsgPendente.First;

         if (MsgPendente.Eof) then
         Begin

            MsgPendente.Append;
            MsgPendente.FieldByName('ID').AsString :=
               Mensagens.FieldByName('ID').AsString;
            MsgPendente.FieldByName('Sequencia').AsString :=
               Mensagens.FieldByName('Sequencia').AsString;
            MsgPendente.FieldByName('Status').AsInteger :=
               Mensagens.FieldByName('Status').AsInteger;
            MsgPendente.FieldByName('Comando').AsString :=
               Mensagens.FieldByName('Comando').AsString;

            if MsgPendente.State in [dsEdit, dsInsert]  then
               MsgPendente.Post;

            Comando := MsgPendente.FieldByName('Comando').AsString;

            if (Mensagens.FieldByName('ID').AsString = Debug_id) then
               SalvaLog(Arq_Log, 'ID/Recebido do Encode: ' + MsgPendente.FieldByName('ID').AsString + ' / ' + '(' + Comando + ')');

         End
         Else if (MsgPendente.FieldByName('Status').AsInteger = 3) then
         Begin

            Mensagens.Edit;
            Mensagens.FieldByName('Status').AsInteger := 3;
            Mensagens.Post;
            MsgPendente.Delete;

         End;

         Mensagens.Next;

      End;

      MsgPendente.Filtered := False;
      MsgPendente.Filter := 'Status = 3';
      MsgPendente.Filtered := true;
      MsgPendente.First;

      while Not MsgPendente.Eof do
      Begin

         Mensagens.Filtered := False;
         Mensagens.Filter := 'ID = ' + QuotedStr(MsgPendente.FieldByName('ID')
            .AsString) + ' and  Sequencia = ' + MsgPendente.FieldByName
            ('Sequencia').AsString;
         Mensagens.Filtered := true;

         If (Mensagens.FieldByName('Status').AsInteger <>
             MsgPendente.FieldByName('Status').AsInteger) then
         Begin

            Mensagens.Edit;
            Mensagens.FieldByName('Status').AsInteger := 3;
            Mensagens.Post;

         End;

         MsgPendente.Delete;
         MsgPendente.First;
      End;

      //Envia os comandos pendentes
      MsgPendente.Filtered := False;
      MsgPendente.Filter := 'Status = 0';
      MsgPendente.Filtered := true;
      MsgPendente.First;

      while Not MsgPendente.Eof do
      Begin
         Try
            Serial     := MsgPendente.FieldByName('ID').AsString;
            Comando    := MsgPendente.FieldByName('Comando').AsString;
            Tamanho    := Trunc(Length(Comando) /2);
            SetLength(PacketEnv,Tamanho);

            If QuantaRec.FindKey([Serial]) Then
            Begin

               for Contador := 0 to (Tamanho -1) do
               Begin
                  PacketEnv[Contador] := StrtoInt('$' + Copy(Comando,(Contador*2) + 1,2));
               End;

               Msgporta                   := QuantaRec.FieldByName('Porta').AsInteger;
               MsgIP                      := QuantaRec.FieldByName('IP').AsString;
               WSocketUdpRec.Close;
               WSocketUdpRec.Addr         := MsgIP;
               WSocketUdpRec.Port         := InttoStr(Msgporta);
               WSocketUdpRec.Proto        := 'udp';
               WSocketUdpRec.LocalAddr    := Srv_Addr;
               WSocketUdpRec.LocalPort    := '10000';
               WSocketUdpRec.LineMode     := False;
               WSocketUdpRec.Connect;     // opens socket
               Resultado                  := WSocketUdpRec.Send(PacketEnv, Tamanho);


               if Resultado > 0 Then
               Begin
                  MsgPendente.Edit;
                  MsgPendente.FieldByName('Status').AsInteger := 3;
                  MsgPendente.Post;
                  SalvaLog(Arq_Log, 'Comando enviado - Serial:Comando ' + Comando + ':' + Serial);
               End;

            End;
         Except
             SalvaLog(Arq_Log, 'ERRO / EXCEPT ao enviar comando Recebido: ' + Comando + ':' + Serial);

         End;
         MsgPendente.Next;
      End;
   Except
      SalvaLog(Arq_Log, 'ERRO / EXCEPT : Transfer?ncia de Comandos:' );
      Result := False;
   End;
End;

{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
{ WEBTECH }
procedure TTcpSrvForm.ClientDataAvailable_WEBTECH(Sender: TObject; Error: Word);
Var
   Contador: Integer;
   BytesTot: Integer;
   LinhaRec: String;
   LinhaProc: String;
   Separador: String;
   BytesIni: Integer;
   Login: Boolean;
   TmpStr: String;
   Size: Word;

Begin

   Login := False;

   with Sender as TTcpSrvClient do
   begin

      if Error <> 0 then
      Begin
         SalvaLog(Arq_Log, 'Erro: ' + InttoStr(Error) + WSocketErrorDesc(Error)
            + ' - ' + GetPeerAddr + ':' + GetPeerPort);
         Exit;
      End;

      BytesTot := Receive(@PacketRec, Sizeof(PacketRec));

      if BytesTot <= 0 then
         Exit;

      RcvdPacket := '';

      for Contador := 0 to BytesTot - 1 do
         RcvdPacket := RcvdPacket + Chr(PacketRec[Contador]);

      if (Debug in [1, 5, 9]) or (Debug_ID = Id) then
         SalvaLog(Arq_Log, 'Recebido: ' + RcvdPacket + ' - ' + GetPeerAddr + ':'
            + GetPeerPort)
      Else if (Copy(RcvdPacket, 1, 5) <> 'login') and
         (Copy(RcvdPacket, 1, 8) <> 'L0 L3,01') and
         (Copy(RcvdPacket, 1, 3) <> 'C0 ') then
      Begin

         TmpStr := '';
         for Contador := 0 to BytesTot - 1 do
            TmpStr := TmpStr + InttoStr(Ord(PacketRec[Contador])) + ':';
         SalvaLog(Arq_Log, 'Pacote n?o Previsto <T> ? : ' + TmpStr);

      End;

      BytesIni := 1;

      while BytesIni < BytesTot do
      Begin

         LinhaRec := '';
         if (Pos(Char(10), RcvdPacket) = 0) and (Pos(Char(13), RcvdPacket) = 0)
         then
         Begin
            LinhaRec := RcvdPacket;
            BytesIni := BytesTot;
         End
         Else
         Begin
            BytesIni := Pos(Char(10), RcvdPacket);
            if BytesIni = 0 then
               BytesIni := Pos(Char(13), RcvdPacket);
            LinhaRec := Copy(RcvdPacket, 1, BytesIni - 1);
            Inc(BytesIni);
         End;

         // Se for Login So salva o ID do Equipamento
         if Pos('login ', LinhaRec) > 0 then
         Begin
            // Para identificar o protocolo, o <t> vem primeiro o Login
            // O <T> vem primeiro 2 octetos com o tamanho  disponivel no pacote
            if Copy(LinhaRec, 1, 5) = 'login' then
            Begin
               Protocolo := 't'; // login <id> <opt>\n
               LinhaRec := Copy(LinhaRec, Pos('login ', LinhaRec) + 6, 1500);
            End
            Else
            Begin
               Protocolo := 'T'; // <length>login <id> <opt>
               SalvaLog(Arq_Log, 'Pacote T recebido: ' + LinhaRec);
               Size := (PacketRec[0] * 256) + PacketRec[1];
               LinhaRec := Copy(LinhaRec, Pos('login ', LinhaRec) + 6, Size);
            End;

            Separador := ' ';

            StringProcessar(LinhaRec, LinhaProc, Separador);
            if LinhaProc <> '' Then
               Id := Trim(LinhaProc);

            if LinhaProc <> '' Then
               FirmWare := Trim(LinhaRec);

            // Se o ID recebido for pelo menos um numero valido...
            if paraInteiro(Id) > 0 then
            Begin

               Login := true;

               Recebidos.Append;
               Recebidos.FieldByName('TCP_CLIENT').AsInteger := CliId;
               Recebidos.FieldByName('IP').AsString := GetPeerAddr;
               Recebidos.FieldByName('Porta').AsString := GetPeerPort;
               Recebidos.FieldByName('ID').AsString := Id;
               Recebidos.FieldByName('MsgSequencia').AsInteger := 0;
               Recebidos.FieldByName('DataGrama').AsString := 'login';
               Recebidos.FieldByName('Processado').AsBoolean := False;

               Recebidos.Post;

            End;

            BytesIni := Pos('L0 L3,01,', LinhaRec);
            if BytesIni > 0 then
            Begin
               LinhaRec := Copy(LinhaRec, BytesIni, 1500);
               Continue
            End
            Else
               BytesIni := BytesTot;

         End

         // Senao Salva o Pacote para processar
         Else if Id <> '' then
         Begin

            while Recebidos.ReadOnly do
            Begin
               Sleep(1);
               SalvaLog(Arq_Log, 'Aguardando Destravar Arquivo Recebido: ');
            End;

            Inc(NumpackRec);
            Inc(NumPackEst);

            if Protocolo = 'T' then
               LinhaRec := Copy(LinhaRec, 3, 1500);

            Recebidos.Append;
            Recebidos.FieldByName('TCP_CLIENT').AsInteger := CliId;
            Recebidos.FieldByName('IP').AsString := GetPeerAddr;
            Recebidos.FieldByName('Porta').AsString := GetPeerPort;
            Recebidos.FieldByName('ID').AsString := Id;
            Recebidos.FieldByName('MsgSequencia').AsInteger := MsgSequencia;
            Recebidos.FieldByName('DataGrama').AsString := LinhaRec;
            Recebidos.FieldByName('Processado').AsBoolean := False;
            Recebidos.Post;

            // Atualiza pacotes recebidos / mensagens Enviadas deste cliente
            NumRecebido := NumRecebido + 1;
            UltMensagem := Now;
            BytesIni := BytesTot;

         End
         // Recebeu dados e n?o logou ainda ?
         Else if Copy(LinhaRec, 1, 5) = 'GET /' then
         Begin
            Inc(ErroLogin);
            if (ErroLogin Mod 100 = 0) then
               SalvaLog(Arq_Log, 'Desconectando... Recebeu dados repetidos: ' +
                  InttoStr(ErroLogin) + ' Ocorrencias :' + LinhaRec +
                  ' - IP:Porta' + GetPeerAddr + ':' + GetPeerPort);
            CloseDelayed;
         End
         Else if Id = '' then
         Begin
            SalvaLog(Arq_Log, 'Desconectando... Recebeu dados sem login:' +
               LinhaRec + ' - IP:Porta' + GetPeerAddr + ':' + GetPeerPort);
            CloseDelayed;
         End;

      End;

      // Envia ACK Se o Protocolo For = <T>
      if Protocolo = 'T' then
         Try
            SendStr(Char(0) + Char(0));
            if Debug in [1, 5, 9] then
               SalvaLog(Arq_Log, 'ACK Enviado: ' + GetPeerAddr + ':' +
                  GetPeerPort);
         Except
            SalvaLog(Arq_Log, 'Erro ao enviar ACK: ' + GetPeerAddr + ':' +
               GetPeerPort);
         End
      Else if Login and (cmd_pos_login <> '') then
         Try
            Size := Length(cmd_pos_login);
            if Protocolo = 't' then
               SendStr(cmd_pos_login + Chr(13) + Chr(10))
            Else
               SendStr(Char(0) + Char(Size) + cmd_pos_login);

            if Debug in [1, 5, 9] then
               SalvaLog(Arq_Log, 'Enviado CMD_POS_LOGIN: ' + cmd_pos_login);
         Except
            SalvaLog(Arq_Log, 'Erro ao enviar CMD_POS_LOGIN: ' + cmd_pos_login);
         End;

      Inc(NumpackRec);
      Inc(NumPackEst);
      pacotes.Caption := InttoStr(NumpackRec);
      PacotesSeg.Caption := FormatFloat('##0',
         NumpackRec / ((Now - ServerReStartUp) * 24 * 60 * 60));

   end;

end;

//SUNTECH
{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
procedure TTcpSrvForm.ClientDataAvailable_SunTech(Sender: TObject; Error: Word);
Var
   Contador: Integer;
   BytesTot: Integer;
   Separador: String;
//   BytesIni: Integer;
   TmpStr1: String;
   TmpStr2: String;
   cmd_ack: String;
   Suntech_Header: Pack_SunTech;

Begin

   Separador := ';';

   with Sender as TTcpSrvClient do
   begin

      if Error <> 0 then
      Begin
         SalvaLog(Arq_Log, 'Erro: ' + InttoStr(Error) + WSocketErrorDesc(Error)
            + ' - ' + GetPeerAddr + ':' + GetPeerPort);
         Exit;
      End;

      BytesTot := Receive(@PacketRec, Sizeof(PacketRec));

      if BytesTot <= 0 then
         Exit;

      RcvdPacket := '';

      for Contador := 0 to BytesTot - 1 do
      if (PacketRec[Contador]  <> 10) and (PacketRec[Contador]  <> 13)  then
         RcvdPacket := RcvdPacket + Chr(PacketRec[Contador]);

//      BytesIni := 1;
      TmpStr1  := RcvdPacket;

      StringProcessar(TmpStr1, TmpStr2, Separador);
      Suntech_Header.HDR      := Trim(TmpStr2);

      StringProcessar(TmpStr1, TmpStr2, Separador);

      //Pacotes STT/ALT/ALV Diretos
      //Outros sao Res = Resposta
      if TmpStr2 = 'Res' then
         StringProcessar(TmpStr1, TmpStr2, Separador);

      Suntech_Header.DeviceID := Trim(TmpStr2);

      ID := TmpStr2;

      // Se nao for KeepAlive Salva o Pacote para processar
      if Suntech_Header.HDR = 'SA200ALV' then
      Begin
         UltMensagem := Now;
         Inc(NumpackRec);
         Inc(NumPackEst);
      End
      Else
      Begin

         while Recebidos.ReadOnly do
         Begin
            Sleep(1);
            SalvaLog(Arq_Log, 'Aguardando Destravar Arquivo Recebido: ');
         End;

         Inc(NumpackRec);
         Inc(NumPackEst);

         Recebidos.Append;
         Recebidos.FieldByName('TCP_CLIENT').AsInteger      := CliId;
         Recebidos.FieldByName('IP').AsString               := GetPeerAddr;
         Recebidos.FieldByName('Porta').AsString            := GetPeerPort;
         Recebidos.FieldByName('ID').AsString               := Id;
         Recebidos.FieldByName('MsgSequencia').AsInteger    := MsgSequencia;
         Recebidos.FieldByName('DataGrama').AsString        := RcvdPacket;
         Recebidos.FieldByName('Processado').AsBoolean      := False;
         Recebidos.Post;

         // Atualiza pacotes recebidos / mensagens Enviadas deste cliente
         NumRecebido := NumRecebido + 1;
         UltMensagem := Now;
//         BytesIni := BytesTot;

         {envia o Ack de Emergencia Recebida para parar Transmiss?o}
         if Suntech_Header.HDR = 'SA200EMG' then
         Begin
            cmd_ack := 'SA200CMD;' + Suntech_Header.DeviceID + ';02;AckEmerg';
            SendStr(cmd_ack + Chr(10));
//            SalvaLog(Arq_Log, 'ID: ' + id + ' - Ack Enviado: ' + cmd_ack)
         End;

         if (Debug in [2, 5, 9]) or (debug_id = id)  then
            SalvaLog(Arq_Log, 'ID: ' + id + ' - ' + RcvdPacket);
      End;

      Inc(NumpackRec);
      Inc(NumPackEst);
      pacotes.Caption := InttoStr(NumpackRec);
      PacotesSeg.Caption := FormatFloat('##0',
         NumpackRec / ((Now - ServerReStartUp) * 24 * 60 * 60));

   end;

end;

//QUECLINK
{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
procedure TTcpSrvForm.ClientDataAvailable_QUECLINK(Sender: TObject; Error: Word);
Var
   Contador: Integer;
   BytesTot,totpct: Integer;
   Separador,retorno,teste_dat,test_pct,pct_utc,pct_asc,ret_hora,separaasc: String;
//   BytesIni: Integer;
   TmpStr1: String;
   TmpStr2: String;
   Tmpasc: String;
   cmd_ack,agrupa,novo_pte,pct_ascgrava: String;
   i,conta : integer;
   Suntech_Header: Pack_SunTech;

Begin

   Separador := ',';
   separaasc := '#';
   with Sender as TTcpSrvClient do
   begin

      if Error <> 0 then
      Begin
         SalvaLog(Arq_Log, 'Erro: ' + InttoStr(Error) + WSocketErrorDesc(Error)
            + ' - ' + GetPeerAddr + ':' + GetPeerPort);
         Exit;
      End;

      BytesTot :=  Receive(@PacketRec, Sizeof(PacketRec));
//Retorna mensagens
//***********************
//      SendText(copy(retorno,1,23)+'msg#');
/////////      SendText('*ET,SN,MQ#'); jhonny pediu para retirar em 22/07/2015

      if BytesTot <= 0 then
         Exit;
      agrupa := '';

      RcvdPacket := '';
      for Contador := 0 to BytesTot - 1 do
        if Debug_pct = '0' then
          begin
            RcvdPacket := RcvdPacket + IntToHex(PacketRec[Contador], 2) + ',';
            NovoPacket := NovoPacket + HexToAscii(IntToHex(PacketRec[Contador], 2));
            if Contador <= 3 then
              Suntech_Header.HDR := copy(NovoPacket,1,4);
            if (contador > 11) and (contador < 20) and (Suntech_Header.HDR = '+ACK')  then
              if contador = 19 then
                Suntech_Header.DeviceID := Suntech_Header.DeviceID + HexToNumber(IntToHex(PacketRec[Contador], 2))
              else
                Suntech_Header.DeviceID := Suntech_Header.DeviceID + StrZero(HexToNumber(IntToHex(PacketRec[Contador], 2)),2);

            if ((contador > 15) and (contador < 24)) and (Suntech_Header.HDR <> '+ACK')  then
              if contador = 23 then
                Suntech_Header.DeviceID := Suntech_Header.DeviceID + HexToNumber(IntToHex(PacketRec[Contador], 2))
              else
                Suntech_Header.DeviceID := Suntech_Header.DeviceID + StrZero(HexToNumber(IntToHex(PacketRec[Contador], 2)),2);
            if (contador > 4) and (contador < 9)  then
              Suntech_Header.configuracao := Suntech_Header.configuracao + IntToHex(PacketRec[Contador],2);
          end
        else if (Debug_pct = '1') then
          begin
            if not ParImpar(Contador) then
              Begin
                vChar[Contador-1] := agrupa[1] ;
                vChar[Contador] := chr(Ord(PacketRec[Contador]));
             //   PacketRec_novo := PacketRec_novo + pchar(chr(Ord(PacketRec[Contador]))) ;
              End
            else
              agrupa := chr(Ord(PacketRec[Contador]))  ;
          end;
        if (Debug_pct = '1') then
          begin
            totpct := round((length(novo_pte)/2));
            novo_pte := ArrayToString(vChar);
            novo_pte := Copy(novo_pte, 1, Pos(',,', novo_pte)) ;
            novo_pte := StringReplace(novo_pte, ',', '', [rfIgnoreCase, rfReplaceAll]) ;
            totpct := round((length(novo_pte)/2));
            conta := -0;
            for i := 0 to totpct -1 do
              begin
                 if conta = 0 then
                   conta := 1
                 else
                   conta := conta + 2;
                 PacketRec_novo[i] := hexatoint(copy(novo_pte,conta,2));
              end;
          end;
        if Debug_pct = '1' then
          for Contador := 0 to totpct - 1 do
            begin
              RcvdPacket := RcvdPacket + IntToHex(PacketRec_novo[Contador], 2) + ',';
              NovoPacket := NovoPacket + HexToAscii(IntToHex(PacketRec_novo[Contador], 2));
              if Contador <= 3 then
                Suntech_Header.HDR := copy(NovoPacket,1,4);
              if (contador > 15) and (contador < 24)  then
                if contador = 23 then
                  Suntech_Header.DeviceID := Suntech_Header.DeviceID + HexToNumber(IntToHex(PacketRec_novo[Contador], 2))
                else
                  Suntech_Header.DeviceID := Suntech_Header.DeviceID + StrZero(HexToNumber(IntToHex(PacketRec_novo[Contador], 2)),2);
              if (contador > 4) and (contador < 9)  then
                Suntech_Header.configuracao := Suntech_Header.configuracao + IntToHex(PacketRec_novo[Contador],2);
            end ;

//      BytesIni := 1;
      TmpStr1  := RcvdPacket;
      pct_utc := TmpStr1;
      pct_asc := NovoPacket ; // StringReplace(NovoPacket, ?'?, ??, [rfIgnoreCase]) ;
      pct_ascgrava := RetiraAspaSimples(pct_asc);

      ID := Suntech_Header.DeviceID;

      if gravatemp = 'S'  then
        begin
          conn := TZConnection.Create(nil);
          Qry_ret  := TZReadOnlyQuery.Create(nil);

          conn.Properties.Add('compress=1');

          conn.HostName := db_hostname;
          conn.User := db_username;
          conn.Password := db_password;
          conn.Database := db_database;
          conn.Protocol := 'mysql';
          conn.Port := 3306;
          Qry_ret.Connection := conn;
          conn.Properties.Add('sort_buffer_size=4096');
          conn.Properties.Add('join_buffer_size=64536');

          Try
             conn.Connect;
          Except
             SalvaLog(Arq_Log,
                'Thread LerMensagem - Erro ao conectar com o MySql: ');
          End;


          Qry_ret.Close;
          Qry_ret.Sql.Clear;
          Qry_ret.Sql.Add('insert into nexsat.posicao_tmp(porta,id,pacote,marc_codigo,data_rec)');
          Qry_ret.Sql.Add(' values('+QuotedStr(Srv_Port)+','+QuotedStr(ID)+','+QuotedStr(pct_utc)+',' + inttostr(marc_codigo) + ',now());');
          Qry_ret.ExecSQL;
          conn.Disconnect;
          conn.Free;
          Qry_ret.Free;
       end;


      // Se nao for KeepAlive Salva o Pacote para processar
      if (Suntech_Header.HDR = '+BSP') or (Suntech_Header.HDR = '+RSP') or (Suntech_Header.HDR = '+EVT') or (Suntech_Header.HDR = '+BVT') then
      Begin

         while Recebidos.ReadOnly do
         Begin
            Sleep(1);
            SalvaLog(Arq_Log, 'Aguardando Destravar Arquivo Recebido: ');
         End;

         Inc(NumpackRec);
         Inc(NumPackEst);

         Recebidos.Append;
         Recebidos.FieldByName('TCP_CLIENT').AsInteger      := CliId;
         Recebidos.FieldByName('IP').AsString               := GetPeerAddr;
         Recebidos.FieldByName('Porta').AsString            := GetPeerPort;
         Recebidos.FieldByName('ID').AsString               := Id;
         Recebidos.FieldByName('MsgSequencia').AsInteger    := MsgSequencia;
         Recebidos.FieldByName('DataGrama').AsString        := RcvdPacket;
         Recebidos.FieldByName('Processado').AsBoolean      := False;
         Recebidos.Post;

         // Atualiza pacotes recebidos / mensagens Enviadas deste cliente
         NumRecebido := NumRecebido + 1;
         UltMensagem := Now;
//         BytesIni := BytesTot;


         if (Debug in [2, 5, 9]) or (debug_id = id)  then
            SalvaLog(Arq_Log, 'ID: ' + id + ' - ' + RcvdPacket);
      End
      Else
      Begin
         SalvaLog(Arq_Log, 'Pacote n?o previsto ACK ID: ' + Suntech_Header.DeviceID + ' pacote: ' + pct_utc);
      End;

      Inc(NumpackRec);
      Inc(NumPackEst);
      pacotes.Caption := InttoStr(NumpackRec);
      PacotesSeg.Caption := FormatFloat('##0',
         NumpackRec / ((Now - ServerReStartUp) * 24 * 60 * 60));

   end;

end;


//CALAMP
{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
procedure TTcpSrvForm.ClientDataAvailable_CalAmp(Sender: TObject; Error: Word);
Var
   BytesTot: Integer;
   BlobF: TBlobField;
   BufferRec: TStream;
   Contador: Word;
   PackAnterior: String;
//   KeepAliveRes: TByteDynArray;

begin

   with Sender as TTcpSrvClient do
   begin

      if Error <> 0 then
      Begin
         SalvaLog(Arq_Log, 'Erro: ' + InttoStr(Error) + WSocketErrorDesc(Error)
            + ' - ' + GetPeerAddr + ':' + GetPeerPort);
         Exit;
      End;

      BytesTot := Receive(@PacketRec, Sizeof(PacketRec));

      if BytesTot <= 0 then
         Exit;

      Inc(NumpackRec);
      Inc(NumPackEst);
      NumRecebido := NumRecebido + 1;
      UltMensagem := Now;

      Duplicado := 0;
      PackAnterior := RcvdPacket;
      RcvdPacket := '';

      for Contador := 0 to BytesTot - 1 do
         RcvdPacket := RcvdPacket + IntToHex(PacketRec[Contador], 2) + ':';

      if (PackAnterior = RcvdPacket) and (Length(RcvdPacket) >= 20) and
         (Length(PackAnterior) >= 20) then
         Duplicado := 1
      Else
         Duplicado := 0;

      if (Debug in [1, 5, 9]) or (Debug_ID = Id) then
         SalvaLog(Arq_Log, 'Recebido: ' + RcvdPacket);

      while Recebidos.ReadOnly do
      Begin
         Sleep(1);
         SalvaLog(Arq_Log, 'Aguardando Destravar Arquivo Recebido: ');
      End;

      Begin

         Recebidos.Append;
         Recebidos.FieldByName('IP').AsString := GetPeerAddr;
         Recebidos.FieldByName('ID').AsString := Id;
         Recebidos.FieldByName('Porta').AsString := GetPeerPort;
         Recebidos.FieldByName('TCP_CLIENT').AsInteger := CliId;
         Recebidos.FieldByName('Processado').AsBoolean := False;
         Recebidos.FieldByName('MsgSequencia').AsInteger := MsgSequencia;
         Recebidos.FieldByName('Duplicado').AsInteger := Duplicado;

         BlobF := Recebidos.FieldByName('DataGrama') as TBlobField;

         Try
            BufferRec := Recebidos.CreateBlobStream(BlobF, bmWrite);
            try
               BufferRec.Write(PacketRec, BytesTot);
            finally
               BufferRec.Free;
            end;
         Except
            SalvaLog(Arq_Log, 'Erro ao Criar o TBlobField: ');
         End;

         Recebidos.Post;

      End;

      pacotes.Caption := InttoStr(NumpackRec);
      PacotesSeg.Caption := FormatFloat('##0',
         NumpackRec / ((Now - ServerReStartUp) * 24 * 60 * 60));
      // Atualiza pacotes recebidos / mensagens Enviadas deste cliente

   end;

end;

{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
Function TTcpSrvForm.EnviaMsgWebTech(var Mensagens: tClientDataSet): Boolean;
Var
   Contador: Integer;
   Client: TTcpSrvClient;
   Comando: String;
Begin

   Result := False;

   For Contador := WSocketServer1.ClientCount - 1 DownTo 0 do
   Begin

      Client := WSocketServer1.Client[Contador] as TTcpSrvClient;

      With Client as TTcpSrvClient do
      Begin

         If Mensagens.Locate('ID', Id, []) then
         Begin
            Try

               Comando := Mensagens.FieldByName('Mensagem').AsString;
               SendStr(Comando + Char(13) + Char(10));
               Mensagens.Edit;
               Mensagens.FieldByName('Status').AsInteger := 3;
               Mensagens.Post;
               NumMens := NumMens + 1;
               MsgSequencia := Mensagens.FieldByName('Sequencia').AsInteger;
               Result := true;

               If (Debug in [4, 5, 9]) or (Debug_ID = Id) Then
                  SalvaLog(Arq_Log, 'Mensagem Enviada: (ID/Sequencia): (' + Id +
                     ':' + Mensagens.FieldByName('Sequencia').AsString + ')');

            Except
               Close;
            End;

         End;
      End;

   End;
End;


{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
Function TTcpSrvForm.EnviaMsgSunTech(var Mensagens: tClientDataSet): Boolean;
Var
   Contador: Integer;
   Client: TTcpSrvClient;
   Comando: String;
Begin

   Result := False;

   For Contador := WSocketServer1.ClientCount - 1 DownTo 0 do
   Begin

      Client := WSocketServer1.Client[Contador] as TTcpSrvClient;

      With Client as TTcpSrvClient do
      Begin

         If Mensagens.Locate('ID', Id, []) then
         Begin
            Try

               Comando := Mensagens.FieldByName('Mensagem').AsString;
               SendStr(Comando + Char(13) + Char(10));
               Mensagens.Edit;
               Mensagens.FieldByName('Status').AsInteger := 3;
               Mensagens.Post;
               NumMens := NumMens + 1;
               MsgSequencia := Mensagens.FieldByName('Sequencia').AsInteger;
               Result := true;

               If (Debug in [4, 5, 9]) or (Debug_ID = Id) Then
                  SalvaLog(Arq_Log, 'Mensagem Enviada: (ID/Sequencia): (' + Id +
                     ':' + Mensagens.FieldByName('Sequencia').AsString + ')');

            Except
               Close;
            End;

         End;
      End;

   End;
End;

{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
Function TTcpSrvForm.EnviaMsgQUECLINK(var Mensagens: tClientDataSet): Boolean;
Var
   Contador: Integer;
   Client: TTcpSrvClient;
   Comando: String;
Begin

   Result := False;

   For Contador := WSocketServer1.ClientCount - 1 DownTo 0 do
   Begin

      Client := WSocketServer1.Client[Contador] as TTcpSrvClient;

      With Client as TTcpSrvClient do
      Begin

         If Mensagens.Locate('ID', Id, []) then
         Begin
            Try

               Comando := Mensagens.FieldByName('Mensagem').AsString;
               SendStr(Comando + Char(13) + Char(10));
               Mensagens.Edit;
               Mensagens.FieldByName('Status').AsInteger := 3;
               Mensagens.Post;
               NumMens := NumMens + 1;
               MsgSequencia := Mensagens.FieldByName('Sequencia').AsInteger;
               Result := true;

               If (Debug in [4, 5, 9]) or (Debug_ID = Id) Then
                  SalvaLog(Arq_Log, 'Mensagem Enviada: (ID/Sequencia): (' + Id +
                     ':' + Mensagens.FieldByName('Sequencia').AsString + ')');

            Except
               Close;
            End;

         End;
      End;

   End;
End;


{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
Function TTcpSrvForm.EnviaMsgCalAmp(var Mensagens: tClientDataSet): Boolean;
Var
   Contador: Integer;
   Client: TTcpSrvClient;
   Comando: String;
Begin

   Result := False;

   For Contador := WSocketServer1.ClientCount - 1 DownTo 0 do
   Begin

      Client := WSocketServer1.Client[Contador] as TTcpSrvClient;

      With Client as TTcpSrvClient do
      Begin

         If Mensagens.Locate('ID', Id, []) then
         Begin
            Try

               Comando := Mensagens.FieldByName('Mensagem').AsString;
               SendStr(Comando + Char(13) + Char(10));
               Mensagens.Edit;
               Mensagens.FieldByName('Status').AsInteger := 3;
               Mensagens.Post;
               NumMens := NumMens + 1;
               MsgSequencia := Mensagens.FieldByName('Sequencia').AsInteger;
               Result := true;

               If (Debug in [4, 5, 9]) or (Debug_ID = Id) Then
                  SalvaLog(Arq_Log, 'Mensagem Enviada: (ID/Sequencia): (' + Id +
                     ':' + Mensagens.FieldByName('Sequencia').AsString + ')');

            Except
               Close;
            End;

         End;
      End;

   End;
End;


{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
procedure TTcpSrvForm.ClientDataAvailable_GENERICO(Sender: TObject; Error: Word);
Var
   Contador: Integer;
   BytesTot: Integer;

Begin


   with Sender as TTcpSrvClient do
   begin

      if Error <> 0 then
      Begin
         SalvaLog(Arq_Log, 'Erro: ' + InttoStr(Error) + WSocketErrorDesc(Error)
            + ' - ' + GetPeerAddr + ':' + GetPeerPort);
         Exit;
      End;

      BytesTot := Receive(@PacketRec, Sizeof(PacketRec));

      if BytesTot <= 0 then
         Exit;

      RcvdPacket := '';

      for Contador := 0 to BytesTot - 1 do
         RcvdPacket := RcvdPacket + Chr(PacketRec[Contador]);

      SalvaLog(Arq_Log, 'Recebido: ' + RcvdPacket + ' - ' + GetPeerAddr + ':'
            + GetPeerPort);

      Inc(NumpackRec);
      Inc(NumPackEst);
      pacotes.Caption := InttoStr(NumpackRec);
      PacotesSeg.Caption := FormatFloat('##0',
         NumpackRec / ((Now - ServerReStartUp) * 24 * 60 * 60));

   end;

end;

{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
procedure TTcpSrvForm.TimerContadorTimer(Sender: TObject);
  var
    contador : word;
begin

         contador_arquivo := strtoint(conta_arquivos(DirSql+'\*.*'));
         if contador_arquivo > vquant_sql then
           Begin
                   if Encerrado Then
                   Begin
                      Application.Terminate;
                      Exit;
                   End;

                   Encerrado := true;

                   Try

                      // Primeiro tem que fechar o resultado a gravar no tcp Server...
                      // Depois o TCP Server
                      // Depois as threads de gravacao...

                      for Contador := 0 to Num_Threads - 1 do
                      Begin
                         If (RequerAck) and (Assigned(Threadresultado[Contador])) Then
                            Threadresultado[Contador].Encerrar := true;
                      End;

                      TimerGravacao.Enabled := False;
                      TimerOutros.Enabled := False;

                      lbl_mensagem.Color := ClRed;

                      lbl_mensagem.Caption := 'Aguarde... Encerrando Servi?os';
                      TcpSrvForm.Refresh;

                      Try
                         StopTcpUdpServer;
                      Except

                         If Srv_Proto = 'tcp' Then
                         Begin
                            If Assigned(WSocketServer1) Then
                               WSocketServer1.Free;
                         End
                         Else
                         Begin
                            If Assigned(WSocketUdpRec) Then
                               WSocketUdpRec.Free;
                         End;

                      End;

                      Try
                         StopThreads;
                      Except
                      End;

                      SalvaLog(Arq_Log, 'Threads Encerradas');

                      TimerGravacaoTimer(Sender);

                      If Assigned(Recebidos) Then
                         Recebidos.Free;
                      if Assigned(Conexoes) then
                         Conexoes.Free;

                      SalvaLog(Arq_Log, 'Servi?o Encerrado com sucesso! ');

                      Application.Terminate;

                   Except
                      Application.Terminate;
                   End;
           End;


end;

procedure TTcpSrvForm.TimerEstatisticasTimer(Sender: TObject);
var
   myFile: TextFile;

begin
   Try

      // Grava n. de conexoes
      AssignFile(myFile, ExtractFileDir(Application.ExeName) + '\conexoes.txt');
      Rewrite(myFile);
      if Srv_Proto = 'tcp' Then
         Write(myFile, InttoStr(WSocketServer1.ClientCount))
      Else
         Write(myFile, '0');
      CloseFile(myFile);

      // Grava n. de pacotes
      AssignFile(myFile, ExtractFileDir(Application.ExeName) + '\pacotes.txt');
      Rewrite(myFile);
      Write(myFile, FormatFloat('###########0',
         NumPackEst / Timer_estatisticas * 60));
      NumPackEst := 0;
      CloseFile(myFile);

      // Grava StartUp
      AssignFile(myFile, ExtractFileDir(Application.ExeName) + '\startup.txt');
      Rewrite(myFile);
      Write(myFile, InttoStr(DateTimeToTimeStamp(ServerStartUp)));
      CloseFile(myFile);

      // Grava Hora atual
      AssignFile(myFile, ExtractFileDir(Application.ExeName) + '\now.txt');
      Rewrite(myFile);
      Write(myFile, InttoStr(DateTimeToTimeStamp(Now)));
      CloseFile(myFile);

      // Grava Hora atual
      AssignFile(myFile, ExtractFileDir(Application.ExeName) + '\agora.txt');
      Rewrite(myFile);

      Write(myFile, InttoStr(DateTimeToUnix(Now)));
      Write(myFile, InttoStr(DateTimeToTimeStamp(Now)));
      Write(myFile, FormatDateTime('yyyy/mm/dd hh:nn:ss', Now));
      Write(myFile, InttoStr(DateTimeToUnix(Now)));
      Write(myFile, InttoStr(DateTimeToTimeStamp(Now)));
      Write(myFile, FormatDateTime('yyyy/mm/dd hh:nn:ss', Now));
      CloseFile(myFile);

   Except
   End;
end;

procedure TTcpSrvForm.TimerGravacaoTimer(Sender: TObject);
//Var
//   Sql_Pendente: TStringList;
//   Sql: String;
Begin

   Inc(Arq_ThreadId);

   if Arq_ThreadId >= Num_Threads then
      Arq_ThreadId := 0;

   Recebidos.ReadOnly := true;

   if Recebidos.RecordCount > 0 then
   Begin

      Recebidos.SaveToFile(ExtractFileDir(Application.ExeName) + '\inbox\' +
         FormatDateTime('yyyy-mm-dd_hh-nn-ss', Now) + '.' + Copy(Srv_Equipo, 1,
         3) + FormatFloat('00', Arq_ThreadId));

      // NumRegistros := Recebidos.RecordCount;

      Recebidos.EmptyDataSet;
      Recebidos.Close;
      Recebidos.Open;

{Desativado
      Try
         Try

            Sql_Pendente := TStringList.Create;
            Sql := GeraSqlStatus(StrTointDef(Srv_Port,0), 0, 0, 0, 1);
            Sql_Pendente.Add(Sql);

            if Sql_Pendente.Count > 0 then
            Begin
               Sql_Pendente.SaveToFile(ExtractFileDir(Application.ExeName) +
                  '\Sql\' + FormatDateTime('yyyy-mm-dd_hh-nn-ss', Now) + '.gat'
                  + FormatFloat('00', Arq_ThreadId));
            End;
         Finally
            Sql_Pendente.Free;
         End;

      Except
         ;
         SalvaLog(Arq_Log, 'Erro ao Salvar SQL: GeraSqlStatus');
      End;
}
   End;

   Recebidos.ReadOnly := False;

   TcpSrvForm.Refresh;


end;

procedure TTcpSrvForm.TimerOutrosTimer(Sender: TObject);
Var
   Contador: Integer;
   Client: TTcpSrvClient;
   // lHour, lMin, lSec, lMSec : Word;
   nDesconectados1: Integer;
   nDesconectados2: Integer;
   nDesconectados3: Integer;
begin

Arq_Log := ExtractFileDir(Application.ExeName) + '\logs\' +
FormatDateTime('yyyy-mm-dd', Now) + '.log';

   if Srv_Proto = 'tcp' then
   Begin

      nDesconectados1 := 0;
      nDesconectados2 := 0;
      nDesconectados3 := 0;

      if (WSocketServer1.ClientCount > 0) then
         For Contador := WSocketServer1.ClientCount - 1 DownTo 0 do
         Begin

            Client := WSocketServer1.Client[Contador] as TTcpSrvClient;

            With Client as TTcpSrvClient do
            Begin
               // Se Conectado a mais de uma hora
               // Se Nao enviou mensagem na ultima hora
               if (Srv_Equipo = 'QUANTA_ACP') and (Client.Duplicado = 1) then
               Begin
                  Send(UltimoAck, Length(UltimoAck));
                  Client.CloseDelayed;
                  Inc(nDesconectados1);
               End
               Else if (((Now - UltMensagem) * 24 * 60) > 30) and
                  (((Now - ConnectTime) * 24 * 60) > 30) then
               // (30) tempo em minutos sem transmitir
               Begin
                  Client.Close;
                  Inc(nDesconectados2);
               End
               // Se conectado a mais de 5 minutos e nao enviou / Decodificou Mensagem
               Else if (((Now - ConnectTime) * 24 * 60) > 2) and (Id = '') then
               Begin
                  Client.Close;
                  Inc(nDesconectados3);
               End;
            End;

         End;

      If nDesconectados1 > 0 Then
         SalvaLog(Arq_Log, InttoStr(nDesconectados1) +
         ' - Cliente(s) desconectado(s) por duplicidade: ');
      If nDesconectados2 > 0 Then
         SalvaLog(Arq_Log, InttoStr(nDesconectados2) +
         ' - Cliente(s) desconectado(s) por ociosidade: ');
      If nDesconectados3 > 0 Then
         SalvaLog(Arq_Log, InttoStr(nDesconectados3) +
         ' - Cliente(s) desconectado(s) por n?o enviar nada em 2 minutos: ');

   end;

   if Srv_Equipo = 'ACP245' then
   Begin

      if (Now - Thgravacao_acp245_ultimo < 0.0014) then  //2 minutos
         tGravacao.Glyph := tRunning.Glyph
      Else
      Begin
         tGravacao.Glyph := tStoped.Glyph;
         if (Now - ServerReStartUp) > 0.0014 then
         Begin
            SalvaLog(Arq_Log, 'Encerrando por Erro: Thread Grava??o ACP Travada !');
            Self.Close;
         End;
      End;


      if (Now - ThMsgAcp245_ultimo < 0.0014) then //2 minutos
         Tmensagem.Glyph := tRunning.Glyph
      Else
      Begin
         Tmensagem.Glyph := tStoped.Glyph;
         if (Now - ServerReStartUp) > 0.0014 then
         Begin
            SalvaLog(Arq_Log, 'Encerrando por Erro: Thread Mensagem ACP Travada !');
            Self.Close;
         End;
      End;


      if (Now - Thresultado_ultimo < 0.0014) then //2 minutos
         tResultado.Glyph := tRunning.Glyph
      Else
      Begin
         tResultado.Glyph := tStoped.Glyph;
         if (Now - ServerReStartUp) > 0.0014 then
         Begin
            SalvaLog(Arq_Log, 'Encerrando por Erro: Thread Resultado ACK-ACP Travada !');
            Self.Close;
         End;
      End;

   End
   Else if Srv_Equipo = 'QUANTA_ACP' then
   Begin

      if (Now - Thgravacao_Quanta_acp_ultimo < 0.0014) then  //2 minutos
         tGravacao.Glyph := tRunning.Glyph
      Else
      Begin
         tGravacao.Glyph := tStoped.Glyph;
         if (Now - ServerReStartUp) > 0.0014 then
         Begin
            SalvaLog(Arq_Log, 'Encerrando por Erro: Thread Grava??o QUANTA ACP Travada !');
            Self.Close;
         End;
      End;


      if (Now - ThMsgQuanta_Acp_ultimo < 0.0014) then //2 minutos
         Tmensagem.Glyph := tRunning.Glyph
      Else
      Begin
         Tmensagem.Glyph := tStoped.Glyph;
         if (Now - ServerReStartUp) > 0.0014 then
         Begin
            SalvaLog(Arq_Log, 'Encerrando por Erro: Thread Mensagem QUANTA ACP Travada !');
            Self.Close;
         End;
      End;


      if (Now - Thresultado_ultimo < 0.0014) then //2 minutos
         tResultado.Glyph := tRunning.Glyph
      Else
      Begin
         tResultado.Glyph := tStoped.Glyph;
         if (Now - ServerReStartUp) > 0.0014 then
         Begin
            SalvaLog(Arq_Log, 'Encerrando por Erro: Thread Resultado ACK-QUANTA ACP Travada !');
            Self.Close;
         End;
      End;

   End
   Else if Srv_Equipo = 'SATLIGHT' then
   Begin

      if (Now - Thgravacao_satlight_ultimo < 0.0014) then //2 minutos
         tGravacao.Glyph := tRunning.Glyph
      Else
      Begin
         tGravacao.Glyph := tStoped.Glyph;
         if (Now - ServerReStartUp) > 0.0014 then
         Begin
            SalvaLog(Arq_Log, 'Encerrando por Erro: Thread Grava??o SATLIGHT Travada !');
            Self.Close;
         End;
      End;

      if (Now - ThMsgSatlight_ultimo < 0.0014) then  //2 minutos
         Tmensagem.Glyph := tRunning.Glyph
      Else
      Begin
         Tmensagem.Glyph := tStoped.Glyph;
         if (Now - ServerReStartUp) > 0.0014 then
         Begin
            SalvaLog(Arq_Log, 'Encerrando por Erro: Thread Mensagem SATLIGHT Travada !');
            Self.Close;
         End;
      End;

      if (Now - Thresultado_ultimo < 0.0014) then  //2 minutos
         tResultado.Glyph := tRunning.Glyph
      Else
      Begin
         tResultado.Glyph := tStoped.Glyph;
         if (Now - ServerReStartUp) > 0.0014 then
         Begin
            SalvaLog(Arq_Log, 'Encerrando por Erro: Thread Resultado SATLIGHT Travada !');
            Self.Close;
         End;
      End;

   End
   Else if Srv_Equipo = 'WEBTECH' then
   Begin

      if (Now - Thgravacao_webtech_ultimo < 0.0014) then  //2 minutos
         tGravacao.Glyph := tRunning.Glyph
      Else
         tGravacao.Glyph := tStoped.Glyph;

      if (Now - ThMsgWebTech_ultimo < 0.0014) then
         Tmensagem.Glyph := tRunning.Glyph
      Else
         Tmensagem.Glyph := tStoped.Glyph;

      if (Now - Thresultado_ultimo < 0.0014) then
         tResultado.Glyph := tRunning.Glyph
      Else
         tResultado.Glyph := tStoped.Glyph;

   End
   Else if Srv_Equipo = 'SUNTECH' then
   Begin

      if (Now - Thgravacao_Suntech_ultimo < 0.0014) then  //2 minutos
         tGravacao.Glyph := tRunning.Glyph
      Else
         tGravacao.Glyph := tStoped.Glyph;

      if (Now - ThMsgSunTech_ultimo < 0.0014) then
         Tmensagem.Glyph := tRunning.Glyph
      Else
         Tmensagem.Glyph := tStoped.Glyph;

      if (Now - Thresultado_ultimo < 0.0014) then
         tResultado.Glyph := tRunning.Glyph
      Else
         tResultado.Glyph := tStoped.Glyph;

   End
   Else if Srv_Equipo = 'QUECLINK' then
   Begin

      if (Now - Thgravacao_QUECLINK_ultimo < 0.0014) then  //2 minutos
         tGravacao.Glyph := tRunning.Glyph
      Else
         tGravacao.Glyph := tStoped.Glyph;

      if (Now - ThMsgQUECLINK_ultimo < 0.0014) then
         Tmensagem.Glyph := tRunning.Glyph
      Else
         Tmensagem.Glyph := tStoped.Glyph;

      if (Now - Thresultado_ultimo < 0.0014) then
         tResultado.Glyph := tRunning.Glyph
      Else
         tResultado.Glyph := tStoped.Glyph;

   End
   Else if Srv_Equipo = 'CALAMP' then
   Begin

      if (Now - Thgravacao_CalAmp_ultimo < 0.0014) then  //2 minutos
         tGravacao.Glyph := tRunning.Glyph
      Else
         tGravacao.Glyph := tStoped.Glyph;

      if (Now - ThMsgCalAmp_ultimo < 0.0014) then
         Tmensagem.Glyph := tRunning.Glyph
      Else
         Tmensagem.Glyph := tStoped.Glyph;

      if (Now - Thresultado_ultimo < 0.0014) then
         tResultado.Glyph := tRunning.Glyph
      Else
         tResultado.Glyph := tStoped.Glyph;

   End
   Else if Srv_Equipo = 'QUANTA' then
   Begin
      //Seta Como Tudo OK Primeiro
      tGravacao.Glyph := tRunning.Glyph;
      Tmensagem.Glyph := tRunning.Glyph;

      //Se Erro, Seta o Erro !
      for Contador := 0 to Num_Threads-1 do
      Begin

         if (Now - Thgravacao_quanta_ultimo[Contador] > 0.01) then //8 minutos
         Begin
            tGravacao.Glyph := tStoped.Glyph;
            if (Now - ServerReStartUp) > 0.01 then
            Begin
               SalvaLog(Arq_Log, 'Encerrando por Erro: Thread Grava??o QUANTA Travada !' + InttoStr(Contador));
               Self.Close;
            End;
         End;

         if (Now - ThMsgSatlight_ultimo > 0.0028) then  //4 minutos
         Begin
            Tmensagem.Glyph := tStoped.Glyph;
   //         Begin
   //            SalvaLog(Arq_Log, 'Encerrando por Erro: Thread Mensagem QUANTA Travada !'
   //            Self.Close;
   //         End;

         End;

         tResultado.Glyph := tStoped.Glyph;
      End;

   End;
   if (Now - ServerReStartUp) > 0.5 then
   Begin
      SalvaLog(Arq_Log, 'Vai Fechar o TCP/UDP Socket (Autom?tico)');
      StopTcpUdpServer;
      SalvaLog(Arq_Log, 'TCP/UDP Socket Fechado (Autom?tico) ');
      Sleep(1000);
      SalvaLog(Arq_Log, 'Vai Abrir o TCP/UDP Socket (Autom?tico)');
      StartTcpUdpServer;
      SalvaLog(Arq_Log, 'TCP/UDP Socket Aberto (Autom?tico)');
   End
end;

{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
procedure TTcpSrvForm.WSocketUdpEnvDataSent(Sender: TObject; ErrCode: Word);
Begin
   WSocketUdpEnv.Close;
end;

{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
{ This event handler is called when listening (server) socket experienced }
{ a background exception. Should normally never occurs. }
{ tcp }
procedure TTcpSrvForm.WSocketServer1BgException(Sender: TObject; E: Exception;
   var CanClose: Boolean);
begin
   SalvaLog(Arq_Log, 'Server exception occured: ' + E.ClassName + ': ' +
      E.Message);
   CanClose := False; { Hoping that server will still work ! }
end;

{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
{ This event handler is called when listening (server) socket experienced }
{ a background exception. Should normally never occurs. }
{ udp }
procedure TTcpSrvForm.WSocketUdpRecBgException(Sender: TObject; E: Exception;
   var CanClose: Boolean);
begin
   SalvaLog(Arq_Log, 'Server exception occured: ' + E.ClassName + ': ' +
      E.Message);
   CanClose := False; { Hoping that server will still work ! }
end;

{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
{ This event handler is called when a client socket experience a background }
{ exception. It is likely to occurs when client aborted connection and data }
{ has not been sent yet. }
procedure TTcpSrvForm.ClientBgException(Sender: TObject; E: Exception;
   var CanClose: Boolean);
begin
   SalvaLog(Arq_Log, 'Client Exception occured: ' + E.ClassName + ': ' +
      E.Message);
   CanClose := true; { Goodbye client ! }
end;

{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
procedure TTcpSrvForm.DoSocksError(
    Sender  : TObject;
    ErrCode : Integer;
    Msg     : String);
begin
   SalvaLog(Arq_Log, 'Ocorreu um erro no TCP/UDP Server: ' + InttoStr(ErrCode) + ': ' +
      Msg);
end;

{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
procedure TTcpSrvForm.SpeedButton1Click(Sender: TObject);
Var
   Client: TTcpSrvClient;
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

      TcpSrvForm.Width := 478;
      TcpSrvForm.Height := Altura;
      TcpSrvForm.Top := Topo;
      TcpSrvForm.Left := Esquerda;

   End
   Else
   Begin

      TcpSrvForm.Width := 640;
      TcpSrvForm.Height := 479;
      TcpSrvForm.Top := 0;
      TcpSrvForm.Left := 0;

      Conexoes := tClientDataSet.Create(Application);
      Conexoes.FieldDefs.Add('Sequencia', ftInteger, 0, False);
      Conexoes.FieldDefs.Add('ID', ftString, 20, False);
      Conexoes.FieldDefs.Add('IP', ftString, 15, False);
      Conexoes.FieldDefs.Add('Porta', ftInteger, 0, False);
      Conexoes.FieldDefs.Add('Pacotes', ftInteger, 0, False);
      Conexoes.FieldDefs.Add('NumKeepAlive', ftInteger, 0, False);
      Conexoes.FieldDefs.Add('Enviados', ftInteger, 0, False);
      Conexoes.FieldDefs.Add('Dt_ultimo', ftDateTime, 0, False);
      Conexoes.FieldDefs.Add('Firmware', ftString, 15, False);
      Conexoes.FieldDefs.Add('Proto', ftString, 1, False);
      Conexoes.FieldDefs.Add('Packet', ftString, 512, False);
      Conexoes.CreateDataset;

      For Contador := 0 to WSocketServer1.ClientCount - 1 do
      Begin

         Client := WSocketServer1.Client[Contador] as TTcpSrvClient;

         With Client as TTcpSrvClient do
         Begin
            Conexoes.Append;
            Conexoes.FieldByName('Sequencia').AsInteger := CliId;
            Conexoes.FieldByName('ID').AsString := Id;
            Conexoes.FieldByName('IP').AsString := GetPeerAddr;
            Conexoes.FieldByName('Porta').AsString := GetPeerPort;
            Conexoes.FieldByName('Pacotes').AsInteger := NumRecebido;
            Conexoes.FieldByName('Enviados').AsInteger := NumMens;
            Conexoes.FieldByName('FirmWare').AsString := FirmWare;
            Conexoes.FieldByName('Proto').AsString := Protocolo;
            Conexoes.FieldByName('NumKeepAlive').AsInteger := NumKeepAlive;
            if UltMensagem = 0 then
               Conexoes.FieldByName('Dt_Ultimo').Clear
            Else
               Conexoes.FieldByName('Dt_Ultimo').AsDateTime := UltMensagem;
            Conexoes.FieldByName('Packet').AsString := Copy(RcvdPacket, 1, 512);

            Conexoes.Post;
         End;
      End;

      DataSource1.DataSet := Conexoes;
      SpeedButton1.Caption := 'Ocultar Grid';
      DBGrid1.Visible := true;

   End;
end;

procedure TTcpSrvForm.SpeedButton2Click(Sender: TObject);
begin

end;

{ * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * }
procedure TTcpSrvForm.leconfig;
Var
   nomearquivo: String;
var
   ArqIni: TInifile;
begin

   Arq_Log := ExtractFileDir(Application.ExeName) + '\logs\' +
      FormatDateTime('yyyy-mm-dd', Now) + '.log';
   Arq_Sql := ExtractFilePath(Application.ExeName) + '\Logs\' +
      FormatDateTime('yyyy_mm_dd', Now) + '.sql';
   nomearquivo := ChangeFileExt(Application.ExeName, '.ini');

   If Not FileExists(nomearquivo) Then
   Begin
      SalvaLog(Arq_Log, 'Arquivo de Configura??o n?o Encontrado: ' + name);
   End;

   ArqIni := TInifile.Create(nomearquivo);

   DirInbox := ExtractFileDir(Application.ExeName) + '\inbox';
   // Diretorio arquivos recebidos a processar
   DirProcess := ExtractFileDir(Application.ExeName) + '\processa';
   // Diretorio de arquivos recebidos e processados
   DirErros := ExtractFileDir(Application.ExeName) + '\erros';
   // Diretorio de arquivos recebidos e N?o Processados com Sucesso
   DirErrosSql := ExtractFileDir(Application.ExeName) + '\ErrosSql';
   // Diretorio de arquivos recebidos e N?o Processados com Sucesso

   DirSql := ExtractFileDir(Application.ExeName) + '\sql';
   // Diretorio de Comandos Sql n?o Executados
   db_hostname := ArqIni.ReadString('DATABASE', 'HOST', 'IP_SERVIDOR');
   // Ip do banco de dados
   db_username := ArqIni.ReadString('DATABASE', 'USERNAME', 'USUARIO');
   // usuario
   db_password := ArqIni.ReadString('DATABASE', 'PASSWORD', 'SENHA'); // senha
   db_database := ArqIni.ReadString('DATABASE', 'DATABASE', 'DATABASE_MYSQL');
   // nome do database
   db_inserts := ArqIni.ReadInteger('DATABASE', 'INSERTS', 10);
   // Inserts Simultaneo
   db_tablecarga := ArqIni.ReadString('DATABASE', 'TABLECARGA',
      'posicoes_carga_acp'); // nome da tabela de carga
   cpr_db_hostname := ArqIni.ReadString('CPR', 'HOST', 'IP_SERVIDOR');
   // Ip do banco de dados
   cpr_db_username := ArqIni.ReadString('CPR', 'USERNAME', 'USUARIO');
   // usuario
   cpr_db_password := ArqIni.ReadString('CPR', 'PASSWORD', 'SENHA'); // senha
   cpr_db_database := ArqIni.ReadString('CPR', 'DATABASE', 'CPR');
   // nome do database
   Srv_Equipo := ArqIni.ReadString('SERVER', 'EQUIPAMENTO', 'ACP245');
   // Servidor Protocolo = tcp
   marc_codigo := ArqIni.ReadInteger('SERVER', 'MARC_CODIGO', 27);
   // Codigo do equipamento (Marc_codigo)
   gravatemp := ArqIni.ReadString('SERVER', 'GRAVA_TEMP', 'S');
   // grava temporario
   vcontador_arquivo := ArqIni.ReadInteger('SERVER', 'CONTADOR_SQL', 60000);
   // Timer para ver diretorio SQL
   vquant_sql := ArqIni.ReadInteger('SERVER', 'QUANTIDADE_SQL', 20);
   // Quantidade permitida no diretorio SQL
   Srv_Proto := ArqIni.ReadString('SERVER', 'PROTOCOLO', 'tcp');
   // Servidor Protocolo = tcp
   Srv_Port := ArqIni.ReadString('SERVER', 'PORT', '9999');
   // Servidor Porta = 9999
   Srv_Addr := ArqIni.ReadString('SERVER', 'ADDR', '0.0.0.0');
   // Servidor Listen = 0.0.0.0 // todas interfaces
   Debug := ArqIni.ReadInteger('SERVER', 'DEBUG', 0); // Nivel e debug
   Debug_ID := ArqIni.ReadString('SERVER', 'DEBUG_ID', '99999999999999999999');
   Debug_PCT := ArqIni.ReadString('SERVER', 'DEBUG_PCT', '0'); // nivel de debug
   // ID a ser debugado
   cmd_pos_login := ArqIni.ReadString('SERVER', 'CMD_POS_LOGIN', '');
   // Comando a enviar apos o login
   Topo := ArqIni.ReadInteger('SERVER', 'TOPO', 0); // Topo
   Esquerda := ArqIni.ReadInteger('SERVER', 'ESQUERDA', 250); // Esquerda
   Altura := ArqIni.ReadInteger('SERVER', 'ALTURA', 125); // Altura
   Timer_Arquivo := ArqIni.ReadInteger('SERVER', 'TIMER_ARQUIVO', 5);
   // Timer para Fechar arquivo
   Timer_estatisticas := ArqIni.ReadInteger('SERVER', 'TIMER_ESTATISTICAS', 15);
   // Timer para estatisticas
   Num_Clientes := ArqIni.ReadInteger('SERVER', 'CLIENTES', 1000);
   // N?mero m?ximo de clientes simultaneos
   Num_Threads := ArqIni.ReadInteger('SERVER', 'THREADS', 10);
   if Num_Threads > 20 Then
      Num_Threads := 20;

   // N?mero m?ximo de threads de grava?ao
   ArqIni.Free;

   ForceDirectories(ExtractFileDir(Arq_Log));
   ForceDirectories(DirInbox);
   ForceDirectories(DirProcess);
   ForceDirectories(DirErros);
   ForceDirectories(DirErrosSql);
   ForceDirectories(DirSql);
   {O Quanta Tem ack Enviado ap?s Receber, n?o depende do Decode, ent?o n?o iniciar a Thread de Resultado}
   If (Srv_Equipo = 'SATLIGHT') or
      (Srv_Equipo = 'ACP245') or
      (Srv_Equipo = 'QUANTA_ACP') Then
      RequerAck := True;
   {O Quanta Tem ack Enviado ap?s Receber, n?o depende do Decode Ent?o n?o Limpar o diret?rio}
   if (Srv_Equipo = 'SATLIGHT') or
      (Srv_Equipo = 'ACP245') or
      (Srv_Equipo = 'QUANTA_ACP') or
      (Srv_Equipo = 'QUECLINK') or
      (Srv_Equipo = 'SUNTECH') Then
   Begin
      deletefile(DirInbox + '\*.*');
      deletefile(DirProcess + '\*.*');
   End;
end;

Function TTcpSrvForm.HexToAscii(Hex: String): String;
begin
   result := chr(StrToInt('$'+hex));
end;


function TTcpSrvForm.ParImpar(aNum: Integer): Boolean;
begin
  Result := ((aNum div 2) = (aNum/2));
end ;

function TTcpSrvForm.ArrayToString(const a: array of Char): string;
begin
  if Length(a)>0 then
    SetString(Result, PChar(@a[0]), Length(a))
  else
    Result := '';
end;

Function TTcpSrvForm.RetiraAspaSimples(Texto:String):String;
var
  n : Integer;
  NovoTexto : String;
begin
  NovoTexto := '';
  for n := 1 to length(texto) do
  begin
    if copy(texto, n,1) <> Chr(39) then
      NovoTexto := NovoTexto + copy(Texto, n,1)
    else
      NovoTexto := NovoTexto + ' ';
  end;
  Result:=NovoTexto;
end;


end.

