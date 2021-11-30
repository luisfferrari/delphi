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
unit Acp245_01;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  StdCtrls, ExtCtrls, IniFiles, DB, DBClient, DBGrids, Buttons, Grids,
  DateUtils,
  OverbyteIcsWSocket, OverbyteIcsWSocketS, OverbyteIcsWndControl,
  FuncColetor, thread_gravacao_acp, thread_gravacao_webtech,
  thread_resultado, thread_LerMensagem ;


const
  TcpSrvVersion = 702;
  CopyRight     = ' TcpSrv (c) 1999-2010 by François PIETTE. V7.02';
  WM_APPSTARTUP = WM_USER + 1;

type

  { TTcpSrvClient is the class which will be instanciated by server component }
  { for each new client. N simultaneous clients means N TTcpSrvClient will be }
  { instanciated. Each being used to handle only a single client.             }
  { We can add any data that has to be private for each client, such as       }
  { receive buffer or any other data needed for processing.                   }

  TTcpSrvClient = class(TWSocketClient)

  public
    RcvdPacket  : String;
    Id          : String;
    NumRecebido : Integer;
    NumMens     : Integer;
    ConnectTime : TDateTime;
    UltMensagem : TDateTime;
    Protocolo   : String;
    FirmWare    : String;
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
    tRetorno: TSpeedButton;
    tGravacao: TSpeedButton;
    Tmensagem: TSpeedButton;
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
    procedure tRunningClick(Sender: TObject);

  private
    Threadgravacao_acp : gravacao_acp;
    Threadgravacao_webtech : gravacao_webtech;
    ThreadMensagem : LerMensagem;
    Threadresultado : resultado;
    FInitialized : Boolean;
    NumpackRec: Integer;
    DirInbox : String;
    DirProcess : String;
    DirErros : String;
    Arq_Log: String;
    Arq_Sql: String;
    db_hostname,
    db_username,
    db_password,
    db_database,
    Srv_Equipo,
    Srv_Proto,
    Srv_Port,
    Srv_Addr,
    cmd_pos_login: String;
    Altura,Topo,Esquerda: Integer;
    Debug: Shortint;
    db_inserts: Integer;
    WSocketServer1: TWSocketServer;

    procedure WMAppStartup(var Msg: TMessage); message WM_APPSTARTUP;
    procedure ClientDataAvailable_ACP(Sender: TObject; Error: Word);
    procedure ClientDataAvailable_WEBTECH(Sender: TObject; Error: Word);
    procedure ClientBgException(Sender       : TObject;
                                E            : Exception;
                                var CanClose : Boolean);
    procedure ClientLineLimitExceeded(Sender        : TObject;
                                      Cnt           : LongInt;
                                      var ClearData : Boolean);

  public

    Recebidos : TClientDataset;
    Conexoes:   TClientDataset;
    //Variaveis para a thread atualizar o ultimo ciclo
    Thgravacao_acp_ultimo : tDateTime;
    Thgravacao_webtech_ultimo : tDateTime;
    ThMensagem_ultimo : tDateTime;
    Thresultado_ultimo : tDateTime;
    procedure RecebeRetorno(pId: String;  pClient: Integer);
    Function EnviaMensagen(var Mensagens: TClientDataset) : Boolean;
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

NumpackRec := 0;
leconfig;

//Definicao do Arquivo de gravacao dos dados recebidos
recebidos := TClientDataset.Create(Application);
recebidos.FieldDefs.Add('Tcp_Client', ftInteger, 0, False);
recebidos.FieldDefs.Add('IP', ftString, 15, False);
recebidos.FieldDefs.Add('Porta', ftInteger, 0, False);
recebidos.FieldDefs.Add('ID', ftString, 20, False);
recebidos.FieldDefs.Add('Datagrama', ftString, 1540, False);
recebidos.CreateDataset;

if Srv_Equipo = 'ACP' Then
   TcpSrvForm.Caption := 'Multi Gateway ACP - ' +   srv_proto + ' : ' +  srv_port
Else if Srv_Equipo = 'WEBTECH' Then
   TcpSrvForm.Caption := 'Multi Gateway WEBTECH - ' +   srv_proto + ' : ' +  srv_port
Else if Srv_Equipo = 'SATLIGHT' Then
   TcpSrvForm.Caption := 'Multi Gateway SatLight - ' +   srv_proto + ' : ' +  srv_port;

TimerGravacao.Enabled := True;
TcpSrvForm.Width  := 478;
TcpSrvForm.Height := Altura;
TcpSrvForm.Top    := Topo;
TcpSrvForm.Left   := Esquerda;

WSocketServer1                    := TWSocketServer.Create(TcpSrvForm);
WSocketServer1.OnBgException      := WSocketServer1BgException;
WSocketServer1.OnClientConnect    := WSocketServer1ClientConnect;
WSocketServer1.OnClientDisconnect := WSocketServer1ClientDisconnect;
WSocketServer1.MaxClients         := 10000;
WSocketServer1.Banner             := '';

end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TTcpSrvForm.FormShow(Sender: TObject);

begin

   if not FInitialized then
   begin

      FInitialized := TRUE;

      //Inicializa a thread de gravacao no banco de dados
      if Srv_Equipo = 'ACP' then
      Begin
         Threadgravacao_acp := gravacao_acp.Create(true);
         Threadgravacao_acp.db_hostname       := db_hostname;
         Threadgravacao_acp.db_username       := db_username;
         Threadgravacao_acp.db_password       := db_password;
         Threadgravacao_acp.db_database       := db_database;
         Threadgravacao_acp.db_inserts        := db_inserts;
         Threadgravacao_acp.Debug             := Debug;
         Threadgravacao_acp.ArqLog            := Arq_Log;
         Threadgravacao_acp.DirInbox          := DirInbox;
         Threadgravacao_acp.DirProcess        := DirProcess;
         Threadgravacao_acp.DirErros          := DirErros;
         Threadgravacao_acp.Encerrar          := False;
         Threadgravacao_acp.FreeOnTerminate   := True; // Destroi a thread quando terminar de executar
         Threadgravacao_acp.Priority          := tpnormal; // Prioridade Normal
         Threadgravacao_acp.Resume; // Executa a thread
      End
      Else if Srv_Equipo = 'WEBTECH' then
      Begin
         Threadgravacao_webtech := gravacao_webtech.Create(True);
         Threadgravacao_webtech.db_hostname       := db_hostname;
         Threadgravacao_webtech.db_username       := db_username;
         Threadgravacao_webtech.db_password       := db_password;
         Threadgravacao_webtech.db_database       := db_database;
         Threadgravacao_webtech.db_inserts        := db_inserts;
         Threadgravacao_webtech.PortaLocal        := Srv_Port;
         Threadgravacao_webtech.Debug             := Debug;
         Threadgravacao_webtech.Arq_Log           := Arq_Log;
         Threadgravacao_webtech.DirInbox          := DirInbox;
         Threadgravacao_webtech.DirProcess        := DirProcess;
         Threadgravacao_webtech.DirErros          := DirErros;
         Threadgravacao_webtech.Encerrar          := False;
         Threadgravacao_webtech.FreeOnTerminate   := True; // Destroi a thread quando terminar de executar
         Threadgravacao_webtech.Priority          := tpnormal; // Prioridade Normal
         Threadgravacao_webtech.Resume; // Executa a thread
      End;

      //Inicializa a thread de resultados da Gravacao ACP
      Threadresultado := resultado.Create(true);
      Threadresultado.ArqLog            := Arq_Log;
      Threadresultado.DirProcess        := DirProcess;
      Threadresultado.Encerrar          := False;
      Threadresultado.FreeOnTerminate   := True; // Destroi a thread quando terminar de executar
      Threadresultado.Priority          := tpnormal; // Prioridade Normal
      Threadresultado.Resume; // Executa a thread

      //Inicializa a thread de envio de mensagens
      ThreadMensagem := LerMensagem.Create(true);
      ThreadMensagem.db_hostname       := db_hostname;
      ThreadMensagem.db_username       := db_username;
      ThreadMensagem.db_password       := db_password;
      ThreadMensagem.db_database       := db_database;
      ThreadMensagem.Srv_Equipo        := Srv_Equipo;
      ThreadMensagem.Arq_Log           := Arq_Log;
      ThreadMensagem.Encerrar          := False;
      ThreadMensagem.FreeOnTerminate   := True; // Destroi a thread quando terminar de executar
      ThreadMensagem.Priority          := tpnormal; // Prioridade Normal
      ThreadMensagem.PortaLocal        := Srv_Port;
      ThreadMensagem.Debug             := Debug;
      ThreadMensagem.Resume; // Executa a thread

      PostMessage(Handle, WM_APPSTARTUP, 0, 0);

   end;

end;

{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{ This is our custom message handler. We posted a WM_APPSTARTUP message     }
{ from FormShow event handler. Now UI is ready and visible.                 }
procedure TTcpSrvForm.WMAppStartup(var Msg: TMessage);
//var
//    MyHostName : AnsiString;
begin
   WSocketServer1.Proto       := srv_proto;         { Use TCP protocol  }
   WSocketServer1.Port        := srv_port;          { Use telnet port   }
   WSocketServer1.Addr        := srv_addr;          { Use any interface }
   WSocketServer1.ClientClass := TTcpSrvClient;     { Use our component }
   WSocketServer1.Listen;                           { Start litening    }
   SalvaLog(Arq_Log,'TcpServer Inicializado:  ');

end;



{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TTcpSrvForm.FormClose(Sender: TObject; var Action: TCloseAction);
Begin

   lbl_mensagem.Color   := ClRed;
   lbl_mensagem.Caption := 'Aguarde... Fechando conexões';
   TcpSrvForm.Refresh;

   If Srv_Equipo = 'ACP' Then
   Begin
      ThreadGravacao_acp.Encerrar := True;
   End
   Else If Srv_Equipo = 'WEBTECH' Then
   Begin
      ThreadGravacao_webtech.Encerrar := True;
   End;

   ThreadMensagem.Encerrar := True;
   ThreadResultado.Encerrar := True;

//   WSocketServer1.Shutdown(2);
   WSocketServer1.Close;

   TimerGravacaoTimer(Sender);

   Sleep(2000);

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
         LineMode            := False;
         LineEdit            := False;
         LineLimit           := 1400; { Do not accept long lines }
         OnDataAvailable     := ClientDataAvailable_ACP;
         OnLineLimitExceeded := ClientLineLimitExceeded;
         OnBgException       := ClientBgException;
         ConnectTime         := Now;
         Id                  := '';
         ConexoesCount.Caption := InttoStr(TWSocketServer(Sender).ClientCount);
      end;
   End
   Else if Srv_Equipo = 'WEBTECH' then
   Begin
      with Client as TTcpSrvClient do
      begin
         LineMode            := False;
         LineEdit            := False;
         LineEnd             := chr(13);
         LineLimit           := 1400; { Do not accept long lines }
         OnDataAvailable     := ClientDataAvailable_WEBTECH;
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
Function TTcpSrvForm.EnviaMensagen(var Mensagens: TClientDataset) : Boolean;
Var Contador : Integer;
    Client: TTcpSrvClient;
    Comando: String;
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
            Comando := Mensagens.FieldByName('Mensagem').AsString + Char(13)+ Char(10);
            Send(@Comando[1], Length(Comando));
//            SendStr(Mensagens.FieldByName('Mensagem').AsString + Char(13)+ Char(10));
            Mensagens.Edit;
            Mensagens.FieldByName('Status').AsInteger := 1;
            Mensagens.Post;
            NumMens := NumMens + 1;
            Result  := True;
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
procedure TTcpSrvForm.RecebeRetorno(pId: String; pClient: Integer);
Var Contador : Integer;
   Client: TTcpSrvClient;
Begin

if Srv_Equipo = 'ACP' then
Begin
   For Contador := 0 to WSocketServer1.ClientCount - 1 do
   Begin

      Client := WSocketServer1.Client[Contador] as TTcpSrvClient;

      With Client as TTcpSrvClient do
      Begin
         if CliId = pClient  then
            Id := pId;
      End;

   End;
End;
End;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TTcpSrvForm.ClientDataAvailable_ACP(
    Sender : TObject;
    Error  : Word);
Var LinhaRec: String;
begin

   Inc(NumPackRec);
   with Sender as TTcpSrvClient do
   begin

      RcvdPacket := ReceiveStr;

      if Debug in [1,5]  then
         SalvaLog(Arq_Log,'Recebido: ' + RcvdPacket );

      while Recebidos.ReadOnly do
      Begin
         Sleep(1);
      End;

      Begin

         if Length(LinhaRec) > 0 then
         Begin
            Recebidos.Append;
            Recebidos.FieldByName('IP').AsString :=  GetPeerAddr;
            Recebidos.FieldByName('Porta').AsString :=  GetPeerPort;
            Recebidos.FieldByName('TCP_CLIENT').AsInteger :=  CliId;
            Recebidos.FieldByName('DataGrama').AsString :=  LinhaRec;
         End;

      End;

      Recebidos.Post;

      Try
         SendStr('0');
      Except
         SalvaLog(Arq_Log,'Erro ao enviar ACK: ' + GetPeerAddr + ';' + GetPeerPort );
      End;

      Pacotes.Caption := InttoStr(NumpackRec);

        //Atualiza pacotes recebidos / mensagens Enviadas deste cliente
      NumRecebido     := NumRecebido + 1;
{Codigo antigo webtech
   with Sender as TTcpSrvClient do
   begin

      if Error <> 0 then
      Begin
         SalvaLog(Arq_Log,'Erro: ' + IntToStr(Error) + WSocketErrorDesc(Error) +  ' - ' + GetPeerAddr + ':' + GetPeerPort);
         Exit;
      End;

      Separadores := [#13,#10];

      BytesTot := Receive(@BufferRec, Sizeof(BufferRec)-1);

      if BytesTot <= 0 then
         Exit;

      BytesIni := 1;
      //Salva o Pacote recebido
      RcvdPacket := StrPas(BufferRec);

      if Debug in [1,5,9]  then
         SalvaLog(Arq_Log,'Recebido: ' + RcvdPacket +  ' - ' + GetPeerAddr + ':' + GetPeerPort);

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
               Protocolo := 't'  //login <id> <opt>\n
            Else
               Protocolo := 'T'; //<length>login <id> <opt>

            LinhaRec  := Copy(LinhaRec, Pos('login ', LinhaRec) + 6, 1500);
            Separador := ' ';

            StringProcessar(LinhaRec,LinhaProc,Separador);
            if LinhaProc <> '' Then
               Id := Trim(LinhaProc);

            if LinhaProc <> '' Then
               FirmWare := Trim(LinhaRec);

         End

         //Senao Salva o Pacote para processar
         Else if id <> '' then
         Begin

            while Recebidos.ReadOnly do
            Begin
               Sleep(1);
            End;

            Inc(NumPackRec);

            Recebidos.Append;
            Recebidos.FieldByName('TCP_CLIENT').AsInteger :=  CliId;
            Recebidos.FieldByName('IP').AsString :=  GetPeerAddr;
            Recebidos.FieldByName('Porta').AsString :=  GetPeerPort;
            Recebidos.FieldByName('ID').AsString :=  Id;
            Recebidos.FieldByName('DataGrama').AsString :=  LinhaRec;
            Recebidos.Post;

         End
         //Recebeu dados e não logou ainda ?
         Else if id = '' then
         Begin
            SalvaLog(Arq_Log,'Desconectando... Recebeu dados sem login:' + LinhaRec + ' - IP:Porta' + GetPeerAddr + ':' + GetPeerPort);
            CloseDelayed;
         End;

         For Contador := BytesIni to BytesTot-1 do
         if (CharInSet(RcvdPacket[Contador],Separadores)) then
            BytesIni := Contador + 1
         Else
            Break;

      End;

      //Envia ACK Se o Protocolo For = <T>
      if Protocolo = 'T' then
         Try
            SendStr('0');
            if Debug in [1,5,9]  then
               SalvaLog(Arq_Log,'ACK Enviado: ' + GetPeerAddr + ':' + GetPeerPort );
         Except
            SalvaLog(Arq_Log,'Erro ao enviar ACK: ' + GetPeerAddr + ':' + GetPeerPort );
         End;

      Pacotes.Caption := InttoStr(NumpackRec);

        //Atualiza pacotes recebidos / mensagens Enviadas deste cliente
      NumRecebido     := NumRecebido + 1;
      UltMensagem     := Now;

   end;

}
   end;

end;

{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{WEBTECH}
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

      if BytesTot <= 0 then
         Exit;

      BytesIni := 1;
      //Salva o Pacote recebido
      RcvdPacket := StrPas(BufferRec);

      if Debug in [1,5,9]  then
         SalvaLog(Arq_Log,'Recebido: ' + RcvdPacket +  ' - ' + GetPeerAddr + ':' + GetPeerPort);

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
               Protocolo := 't'  //login <id> <opt>\n
            Else
               Protocolo := 'T'; //<length>login <id> <opt>

            LinhaRec  := Copy(LinhaRec, Pos('login ', LinhaRec) + 6, 1500);
            Separador := ' ';

            StringProcessar(LinhaRec,LinhaProc,Separador);
            if LinhaProc <> '' Then
               Id := Trim(LinhaProc);

            if LinhaProc <> '' Then
               FirmWare := Trim(LinhaRec);

            if Pos('L0 l3,01,',LinhaRec) > 0 then
               LinhaRec := Copy(LinhaRec, Pos('L0 l3,01,',LinhaRec),Length(LinhaRec)) + Chr(13) + Char(10);
            Login := True;
         End

         //Senao Salva o Pacote para processar
         Else if id <> '' then
         Begin

            while Recebidos.ReadOnly do
            Begin
               Sleep(1);
            End;

            Inc(NumPackRec);

            Recebidos.Append;
            Recebidos.FieldByName('TCP_CLIENT').AsInteger :=  CliId;
            Recebidos.FieldByName('IP').AsString :=  GetPeerAddr;
            Recebidos.FieldByName('Porta').AsString :=  GetPeerPort;
            Recebidos.FieldByName('ID').AsString :=  Id;
            Recebidos.FieldByName('DataGrama').AsString :=  LinhaRec;
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

         For Contador := BytesIni to BytesTot-1 do
         if (CharInSet(RcvdPacket[Contador],Separadores)) then
            BytesIni := Contador + 1
         Else
            Break;

      End;

      //Envia ACK Se o Protocolo For = <T>
      if Protocolo = 'T' then
         Try
            SendStr('0');
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

{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TTcpSrvForm.TimerGravacaoTimer(Sender: TObject);
Var Contador : Integer;
    Client: TTcpSrvClient;
Begin

Recebidos.ReadOnly := True;

if Recebidos.RecordCount > 0  then
Begin
   Recebidos.SaveToFile( ExtractFileDir(Application.ExeName) + '\inbox\'+ FormatDateTime('yyyy-mm-dd_hh-nn-ss',now) + '.rec');
   Recebidos.EmptyDataSet;
   Recebidos.Close;
   Recebidos.Open;
End;

Recebidos.ReadOnly := False;
TcpSrvForm.Refresh;

//So executa nos segundos definidos para auxiliar
if SecondOf(now) in [0,1,2,3,4] then
   For Contador := WSocketServer1.ClientCount - 1 DownTo 0 do
   Begin

      Client := WSocketServer1.Client[Contador] as TTcpSrvClient;

      With Client as TTcpSrvClient do
      Begin
         if (MinuteOf(Now - UltMensagem) > 15)  and
            (MinuteOf(Now - ConnectTime) > 15) then //15 minutos sem transmitir
            Client.Close;
      End;
   End;

//So executa nos segundos definidos para auxiliar
if SecondOf(now) in [30,31,32,33,34] then
Begin

   if srv_equipo = 'ACP' then
   Begin
      if (SecondOf(Now - Thgravacao_acp_ultimo) <60) then
         tGravacao.Glyph := tRunning.Glyph
      Else
         tGravacao.Glyph := tStoped.Glyph;

      if (SecondOf(Now - ThMensagem_ultimo) <60) then
         tMensagem.Glyph := tRunning.Glyph
      Else
         tMensagem.Glyph := tStoped.Glyph;

      if (SecondOf(Now - Thresultado_ultimo) <60) then
         tMensagem.Glyph := tRunning.Glyph
      Else
         tMensagem.Glyph := tStoped.Glyph;
   End
   Else if srv_equipo = 'WEBTECH' then
   Begin
      if (SecondOf(Now - Thgravacao_webtech_ultimo) <60) then
         tGravacao.Glyph := tRunning.Glyph
      Else
         tGravacao.Glyph := tStoped.Glyph;

      if (SecondOf(Now - ThMensagem_ultimo) < 60) then
         tMensagem.Glyph := tRunning.Glyph
      Else
         tMensagem.Glyph := tStoped.Glyph;

      if (SecondOf(Now - ThResultado_ultimo) <60) then
         tRetorno.Glyph := tRunning.Glyph
      Else
         tRetorno.Glyph := tStoped.Glyph;
   End;
End;

end;

{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{ This event handler is called when listening (server) socket experienced   }
{ a background exception. Should normally never occurs.                     }
procedure TTcpSrvForm.WSocketServer1BgException(
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
If DBGrid1.Visible Then
Begin

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

   Conexoes := TClientDataset.Create(Application);
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
   Conexoes.CreateDataset;

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

procedure TTcpSrvForm.tRunningClick(Sender: TObject);
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
db_hostname          := ArqIni.ReadString('DATABASE' ,'HOST','IP_SERVIDOR');        //Ip do banco de dados
db_username          := ArqIni.ReadString('DATABASE' ,'USERNAME','USUARIO');        //usuario
db_password          := ArqIni.ReadString('DATABASE' ,'PASSWORD','SENHA');          //senha
db_database          := ArqIni.ReadString('DATABASE' ,'DATABASE','DATABASE_MYSQL'); //nome do database
db_inserts           := ArqIni.ReadInteger('DATABASE' ,'INSERTS',10);               //Inserts Simultaneo
Srv_Equipo           := ArqIni.ReadString('SERVER' ,'EQUIPAMENTO','ACP');           //Servidor Protocolo = tcp
Srv_Proto            := ArqIni.ReadString('SERVER' ,'PROTOCOLO','tcp');             //Servidor Protocolo = tcp
Srv_Port             := ArqIni.ReadString('SERVER' ,'PORT','9999');                 //Servidor Porta = 9999
Srv_Addr             := ArqIni.ReadString('SERVER' ,'ADDR','0.0.0.0');              //Servidor Listen = 0.0.0.0 // todas interfaces
debug                := ArqIni.ReadInteger('SERVER' ,'DEBUG',0);                    //Nivel e debug
cmd_pos_login        := ArqIni.ReadString('SERVER' ,'CMD_POS_LOGIN','');            //Comando a enviar apos o login
Topo                 := ArqIni.ReadInteger('SERVER' ,'TOPO',0);                     //Nivel e debug
Esquerda             := ArqIni.ReadInteger('SERVER' ,'ESQUERDA',250);               //Nivel e debugeerlrkrrkrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrcccccccccccccccccccccccccc
Altura               := ArqIni.ReadInteger('SERVER' ,'ALTURA',117);                 //Nivel e debugeerlrkrrkrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrcccccccccccccccccccccccccc

ArqIni.Free;

ForceDirectories(ExtractFileDir(Arq_Log));
ForceDirectories(DirInbox);
ForceDirectories(DirProcess);
ForceDirectories(DirErros);
end;


end.

