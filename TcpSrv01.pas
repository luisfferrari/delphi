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
unit TcpSrv01;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  OverbyteIcsIniFiles, StdCtrls, ExtCtrls,
  OverbyteIcsWSocket, OverbyteIcsWSocketS, OverbyteIcsWndControl,
  Contnrs, FuncColetor, thread_gravacao;

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
    RcvdLine    : String;
    Id          : String;
    ConnectTime : TDateTime;
  end;


  TTcpSrvForm = class(TForm)
    ToolPanel: TPanel;
    WSocketServer1: TWSocketServer;
    conexoes: TLabel;
    Label2: TLabel;
    Label1: TLabel;
    pacotes: TLabel;
    Label3: TLabel;
    PortaOrigem: TEdit;
    TimerGravacao: TTimer;
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure WSocketServer1ClientConnect(Sender: TObject;
      Client: TWSocketClient; Error: Word);
    procedure WSocketServer1ClientDisconnect(Sender: TObject;
      Client: TWSocketClient; Error: Word);
    procedure WSocketServer1BgException(Sender: TObject; E: Exception;
      var CanClose: Boolean);
    procedure TimerGravacaoTimer(Sender: TObject);
  private
    FIniFileName : String;
    FInitialized : Boolean;
    ArqLog: String;
    NumpackRec: Integer;
    Threadgravacao : gravacao;
    MyHandle: Integer;
    procedure WMAppStartup(var Msg: TMessage); message WM_APPSTARTUP;
    procedure ClientDataAvailable(Sender: TObject; Error: Word);
    procedure ProcessData(Client : TTcpSrvClient);
    procedure ClientBgException(Sender       : TObject;
                                E            : Exception;
                                var CanClose : Boolean);
    procedure ClientLineLimitExceeded(Sender        : TObject;
                                      Cnt           : LongInt;
                                      var ClearData : Boolean);
  public
    Tracking : Array[0..4] of tTracking;
    TrackingAtiva : Integer;
    property IniFileName : String read FIniFileName write FIniFileName;
  end;

var
  TcpSrvForm: TTcpSrvForm;

implementation

Var   Threadgravacao           : gravacao;
{$R *.DFM}

const
    SectionWindow      = 'WindowTcpSrv';
    KeyTop             = 'Top';
    KeyLeft            = 'Left';
    KeyWidth           = 'Width';
    KeyHeight          = 'Height';


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TTcpSrvForm.FormCreate(Sender: TObject);
begin
    { Compute INI file name based on exe file name. Remove path to make it  }
    { go to windows directory.                                              }
    FIniFileName := GetIcsIniFileName;
{$IFDEF DELPHI10_UP}
    // BDS2006 has built-in memory leak detection and display
    ReportMemoryLeaksOnShutdown := (DebugHook <> 0);
{$ENDIF}
ArqLog := ChangeFileExt(Application.ExeName,'.log');
NumpackRec := 0;
TrackingAtiva := 0;
TimerGravacao.Enabled := True;

end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TTcpSrvForm.FormShow(Sender: TObject);
var
    IniFile : TIcsIniFile;
begin
    if not FInitialized then begin
        FInitialized := TRUE;

        { Fetch persistent parameters from INI file }
        IniFile      := TIcsIniFile.Create(FIniFileName);
        Width        := IniFile.ReadInteger(SectionWindow, KeyWidth,  Width);
        Height       := IniFile.ReadInteger(SectionWindow, KeyHeight, Height);
        Top          := IniFile.ReadInteger(SectionWindow, KeyTop,
                                            (Screen.Height - Height) div 2);
        Left         := IniFile.ReadInteger(SectionWindow, KeyLeft,
                                            (Screen.Width  - Width)  div 2);
        IniFile.Free;
        { Delay startup code until our UI is ready and visible }
        PostMessage(Handle, WM_APPSTARTUP, 0, 0);
    end;
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TTcpSrvForm.FormClose(Sender: TObject; var Action: TCloseAction);
var
    IniFile : TIcsIniFile;
begin
    { Save persistent data to INI file }
    IniFile := TIcsIniFile.Create(FIniFileName);
    IniFile.WriteInteger(SectionWindow, KeyTop,         Top);
    IniFile.WriteInteger(SectionWindow, KeyLeft,        Left);
    IniFile.WriteInteger(SectionWindow, KeyWidth,       Width);
    IniFile.WriteInteger(SectionWindow, KeyHeight,      Height);
    IniFile.UpdateFile;
    IniFile.Free;
end;




{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{ This is our custom message handler. We posted a WM_APPSTARTUP message     }
{ from FormShow event handler. Now UI is ready and visible.                 }
procedure TTcpSrvForm.WMAppStartup(var Msg: TMessage);
var
    MyHostName : AnsiString;
begin
//    Display(CopyRight);
//    Display(OverbyteIcsWSocket.Copyright);
//    Display(OverbyteIcsWSocketS.CopyRight);
    WSocket_gethostname(MyHostName);
//    Display(' I am "' + String(MyHostName) + '"');
//    Display(' IP: ' + LocalIPList.Text);
    WSocketServer1.Proto       := 'tcp';         { Use TCP protocol  }
    WSocketServer1.Port        := '9999';      { Use telnet port   }
    WSocketServer1.Addr        := '0.0.0.0';     { Use any interface }
    WSocketServer1.ClientClass := TTcpSrvClient; { Use our component }
    WSocketServer1.Listen;                       { Start litening    }

end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TTcpSrvForm.WSocketServer1ClientConnect(
    Sender : TObject;
    Client : TWSocketClient;
    Error  : Word);
begin
    with Client as TTcpSrvClient do begin
{
        Display('Client connected.' +
                ' Remote: ' + PeerAddr + '/' + PeerPort +
                ' Local: '  + GetXAddr + '/' + GetXPort);
        Display('There is now ' +
                IntToStr(TWSocketServer(Sender).ClientCount) +
                ' clients connected.');
}
        LineMode            := False;
        LineEdit            := TRUE;
        LineLimit           := 200; { Do not accept long lines }
        OnDataAvailable     := ClientDataAvailable;
        OnLineLimitExceeded := ClientLineLimitExceeded;
        OnBgException       := ClientBgException;
        ConnectTime         := Now;
        Id                  := '';
        conexoes.Caption    := InttoStr( TWSocketServer(Sender).ClientCount);
    end;
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TTcpSrvForm.WSocketServer1ClientDisconnect(
    Sender : TObject;
    Client : TWSocketClient;
    Error  : Word);
begin
    with Client as TTcpSrvClient do begin
            SalvaLog(ArqLog,'Client disconnecting: ' + PeerAddr + '   ' +
                'Duration: ' + FormatDateTime('hh:nn:ss',
                Now - ConnectTime));
        conexoes.Caption    := InttoStr( TWSocketServer(Sender).ClientCount -1);
    end;
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TTcpSrvForm.ClientLineLimitExceeded(
    Sender        : TObject;
    Cnt           : LongInt;
    var ClearData : Boolean);
begin
    with Sender as TTcpSrvClient do begin
        SalvaLog(ArqLog,'Line limit exceeded from ' + GetPeerAddr + '. Closing.');
        ClearData := TRUE;
        Close;
    end;
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TTcpSrvForm.ClientDataAvailable(
    Sender : TObject;
    Error  : Word);
begin
    with Sender as TTcpSrvClient do begin
        { We use line mode. We will receive complete lines }
        RcvdLine := ReceiveStr;
        SalvaLog(ArqLog,'Recebido: ' + RcvdLine);

        Tracking[TrackingAtiva].datagrama := RcvdLine;

        ProcessData(Sender as TTcpSrvClient);
        Inc(NumPackRec);
        Pacotes.Caption := InttoStr(NumpackRec);
    end;
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TTcpSrvForm.ProcessData(Client : TTcpSrvClient);

begin
    { We could replace all those CompareText with a table lookup }
    If Client.Id = '' Then
       Client.Id := Copy(Client.RcvdLine,1,20);
    Client.SendStr('Ack:' + Client.Id);
end;


procedure TTcpSrvForm.TimerGravacaoTimer(Sender: TObject);
Var TrackingAnterior: integer;
begin
TrackingAnterior := TrackingAtiva;


if TrackingAtiva = 4 then
   TrackingAtiva := 0
Else
   Inc(TrackingAtiva);

MyHandle :=  FindWindow('TColetorMaxtrack',nil);
Sleep(10);
Threadgravacao := gravacao.Create(true)  ;

begin


   Threadgravacao.MainHandle        := MyHandle;
   Threadgravacao.db_hostname       := '10.20.1.30';
   Threadgravacao.db_username       := 'SYSDBA';
   Threadgravacao.db_database       := 'NEXSAT';
   Threadgravacao.db_password       := 'masterkey';
   Threadgravacao.db_inserts        := 50 ;
   Threadgravacao.trackingatual     := Tracking[TrackingAnterior];

   Threadgravacao.FreeOnTerminate   := True; // Destroi a thread quando terminar de executar
   Threadgravacao.Priority          := tphigher; // Prioridade alta
   Threadgravacao.Resume; // Executa a thread

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
    SalvaLog(ArqLog,'Server exception occured: ' + E.ClassName + ': ' + E.Message);
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
    SalvaLog(ArqLog,'Client exception occured: ' + E.ClassName + ': ' + E.Message);
    CanClose := TRUE;   { Goodbye client ! }
end;


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}

end.

