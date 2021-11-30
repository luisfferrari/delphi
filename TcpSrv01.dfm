object TcpSrvForm: TTcpSrvForm
  Left = 327
  Top = 392
  Caption = 'Gateway - ACP 245'
  ClientHeight = 182
  ClientWidth = 269
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = True
  OnClose = FormClose
  OnCreate = FormCreate
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object conexoes: TLabel
    Left = 211
    Top = 88
    Width = 6
    Height = 13
    Alignment = taRightJustify
    Caption = '0'
  end
  object Label2: TLabel
    Left = 8
    Top = 88
    Width = 97
    Height = 13
    Caption = 'Clientes Conectados'
  end
  object Label1: TLabel
    Left = 8
    Top = 120
    Width = 88
    Height = 13
    Caption = 'Pacotes recebidos'
  end
  object pacotes: TLabel
    Left = 211
    Top = 120
    Width = 6
    Height = 13
    Alignment = taRightJustify
    Caption = '0'
  end
  object Label3: TLabel
    Left = 8
    Top = 55
    Width = 64
    Height = 13
    Caption = 'Porta Escuta:'
  end
  object ToolPanel: TPanel
    Left = 0
    Top = 0
    Width = 269
    Height = 41
    Align = alTop
    TabOrder = 0
  end
  object PortaOrigem: TEdit
    Left = 96
    Top = 47
    Width = 121
    Height = 21
    Alignment = taRightJustify
    ReadOnly = True
    TabOrder = 1
    Text = '9999'
  end
  object WSocketServer1: TWSocketServer
    LineMode = False
    LineLimit = 65536
    LineEnd = #13#10
    LineEcho = False
    LineEdit = False
    Proto = 'tcp'
    LocalAddr = '127.0.0.1'
    LocalPort = '0'
    MultiThreaded = False
    MultiCast = False
    MultiCastIpTTL = 1
    FlushTimeout = 60
    SendFlags = wsSendNormal
    LingerOnOff = wsLingerOn
    LingerTimeout = 0
    KeepAliveOnOff = wsKeepAliveOff
    KeepAliveTime = 0
    KeepAliveInterval = 0
    SocksLevel = '5'
    SocksAuthentication = socksNoAuthentication
    LastError = 0
    ReuseAddr = False
    ComponentOptions = []
    ListenBacklog = 5
    ReqVerLow = 1
    ReqVerHigh = 1
    OnBgException = WSocketServer1BgException
    Banner = 'Welcome to OverByte ICS TcpSrv'
    BannerTooBusy = 'Sorry, too many clients'
    MaxClients = 0
    OnClientDisconnect = WSocketServer1ClientDisconnect
    OnClientConnect = WSocketServer1ClientConnect
    Left = 128
    Top = 96
  end
  object TimerGravacao: TTimer
    Enabled = False
    Interval = 5000
    OnTimer = TimerGravacaoTimer
    Left = 232
    Top = 48
  end
end
