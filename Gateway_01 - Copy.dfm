object TcpSrvForm: TTcpSrvForm
  Left = 327
  Top = 392
  Caption = 'Multi Gateway'
  ClientHeight = 342
  ClientWidth = 462
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
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 462
    Height = 81
    Align = alTop
    TabOrder = 1
    object lbl_mensagem: TLabel
      Left = 1
      Top = 1
      Width = 460
      Height = 13
      Align = alTop
      AutoSize = False
      Color = clBtnFace
      ParentColor = False
      ExplicitLeft = -8
      ExplicitTop = 49
      ExplicitWidth = 313
    end
    object pacotes: TLabel
      Left = 152
      Top = 30
      Width = 6
      Height = 13
      Alignment = taRightJustify
      Caption = '0'
    end
    object ConexoesCount: TLabel
      Left = 152
      Top = 15
      Width = 6
      Height = 13
      Alignment = taRightJustify
      Caption = '0'
    end
    object Label2: TLabel
      Left = 8
      Top = 11
      Width = 97
      Height = 13
      Caption = 'Clientes Conectados'
    end
    object Label1: TLabel
      Left = 17
      Top = 30
      Width = 88
      Height = 13
      Caption = 'Pacotes recebidos'
    end
    object SpeedButton1: TSpeedButton
      Left = 232
      Top = 4
      Width = 89
      Height = 21
      Caption = 'Mostrar Grid'
      OnClick = SpeedButton1Click
    end
    object tStoped: TSpeedButton
      Left = 426
      Top = 61
      Width = 23
      Height = 22
      Glyph.Data = {
        76060000424D7606000000000000360400002800000018000000180000000100
        0800000000004002000000000000000000000001000000010000FF00FF007777
        7700787878007D7D7D008080800086868600888888008D8D8D00919191009494
        9400999999009D9D9D00A1A1A100A6A6A600AAAAAA00ADADAD00B1B1B100B4B4
        B400B9B9B900BEBEBE00C1C1C100C5C5C500CACACA00CCCCCC00D2D2D200D7D7
        D700000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000080C0E000000000000000000000000000000
        0000000000080C16140B000000000000000000000000000000000000080C1014
        10080000000000000000000000000808080808080C12140E0800000000000000
        00000000000808081014161614081008000000000000000000000000080B120E
        0B14161614120800000000000000000000000000000810141008141412120800
        0000000000000000000000000000081418100810121208000000000000000000
        0000000000000008141410081012080000000000000000000000001600000000
        0812120E0810080000000000000000040000160E04000000000810120E080800
        000000000000040804160E040016000000000B10120B08000000000000040810
        1408040016100400000000080B080000000000000004040C181808160E040016
        00000000080000000000000000040B0412181004040016100400000000000000
        0000000000040E0E040C0E0804160E0400000000000000000000000000041010
        0B040808080404000000000000000000000000000004100C0B08040408040400
        00000000000000000000000000040C0B08040404040804010000000000000000
        00000000040B040804080404010101000000000000000000000000040B140404
        010101010101000000000000000000000000040E160804010000000000000000
        0000000000000000000008140804010000000000000000000000000000000000
        0000010404010000000000000000000000000000000000000000}
      Visible = False
    end
    object tRunning: TSpeedButton
      Left = 423
      Top = 33
      Width = 23
      Height = 22
      Glyph.Data = {
        76060000424D7606000000000000360400002800000018000000180000000100
        0800000000004002000000000000000000000001000000010000FF00FF00004B
        0000004D000000550000015B0100005E000002590500035E0800006001000164
        010000690000016C0200036D060006650A0005650C000172020003760500007E
        0000047209000477090005790A00066C1000096E1100087315000A791900004C
        3500004C3900004C6300004C68000081000003870500038C0600078A13000F80
        1D000A8A18000C891D0011921F000FA51B000D8C2100109A2800119C29001699
        300012A92E0013A032001FA63A0018AC3B0018AF3D001FBC37001BB643001FBD
        4D0024AF410028CE47002DD44E0025C4520037E25F0038E36C003FE96F00004D
        C2000150C6000353CA000456CE00075CD5000A63D9000C65D9000B63DD00116E
        D9000D68E100116DE7001370E7001370EB001877F3001979F3001C7DF3001C7E
        FB001D80E7001F81FF002083E7002186E700268CF3002083FF00288FFF002B92
        F3002D96F3002E98F3002A92FF002C93FF002E98FF00329CF300309AFF00329D
        FF00349FFF0000BDFF0036A1FF0039A6FF0042B1FF0043B4FF0046B7FF0007E9
        E700000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000003940000000000000000000000000000000
        000000000039393B3D3900000000000000000000000000000000000039404139
        39000000005B5B5B000000000000000000000039405D553D390000006161615B
        0000000000000000000039404A58463A000000000000615B5B5B000039393939
        3939404E58423A000000000000006161610000393B3948585F5F583946390000
        00000000000000000000393B49433A575F5C554B390000000000000000000000
        00061C3A48554D3A51554B4B3900000000000000000000000617071C39515F4D
        3A48494B3900000000000000000000060E31350E1B3A57564439454B39000000
        0000000000000006062937380E1A3A484B433943390000000000000000000006
        200632362F06193A464B43393900000000000000000000062A2B0624251F0319
        3A46493B390000000000000000000006302E26060F1D1103193A3B3900000000
        00000000000000062E272212060A1D1106193900000000000000000000000006
        2722140A0906061D0301005B5B5B0000000000000000062201120A0A0A090101
        01006161615B000000000000000621340A0101030101010100000000615B5B5B
        00000000062C340F030100000000000000000000616161000000000616331F06
        0100000000000000000000000000000000000001010906010000000000000000
        0000000000000000000006150301010000000000000000000000000000000000
        0000001806000000000000000000000000000000000000000000}
      Visible = False
    end
    object tResultado: TSpeedButton
      Left = 327
      Top = 53
      Width = 132
      Height = 26
      Caption = 'Thread Retorno    '
      Flat = True
      Glyph.Data = {
        76060000424D7606000000000000360400002800000018000000180000000100
        0800000000004002000000000000000000000001000000010000FF00FF007777
        7700787878007D7D7D008080800086868600888888008D8D8D00919191009494
        9400999999009D9D9D00A1A1A100A6A6A600AAAAAA00ADADAD00B1B1B100B4B4
        B400B9B9B900BEBEBE00C1C1C100C5C5C500CACACA00CCCCCC00D2D2D200D7D7
        D700000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000080C0E000000000000000000000000000000
        0000000000080C16140B000000000000000000000000000000000000080C1014
        10080000000000000000000000000808080808080C12140E0800000000000000
        00000000000808081014161614081008000000000000000000000000080B120E
        0B14161614120800000000000000000000000000000810141008141412120800
        0000000000000000000000000000081418100810121208000000000000000000
        0000000000000008141410081012080000000000000000000000001600000000
        0812120E0810080000000000000000040000160E04000000000810120E080800
        000000000000040804160E040016000000000B10120B08000000000000040810
        1408040016100400000000080B080000000000000004040C181808160E040016
        00000000080000000000000000040B0412181004040016100400000000000000
        0000000000040E0E040C0E0804160E0400000000000000000000000000041010
        0B040808080404000000000000000000000000000004100C0B08040408040400
        00000000000000000000000000040C0B08040404040804010000000000000000
        00000000040B040804080404010101000000000000000000000000040B140404
        010101010101000000000000000000000000040E160804010000000000000000
        0000000000000000000008140804010000000000000000000000000000000000
        0000010404010000000000000000000000000000000000000000}
    end
    object tGravacao: TSpeedButton
      Left = 327
      Top = 1
      Width = 132
      Height = 26
      Caption = 'Thread Grava'#231#227'o'
      Flat = True
      Glyph.Data = {
        76060000424D7606000000000000360400002800000018000000180000000100
        0800000000004002000000000000000000000001000000010000FF00FF007777
        7700787878007D7D7D008080800086868600888888008D8D8D00919191009494
        9400999999009D9D9D00A1A1A100A6A6A600AAAAAA00ADADAD00B1B1B100B4B4
        B400B9B9B900BEBEBE00C1C1C100C5C5C500CACACA00CCCCCC00D2D2D200D7D7
        D700000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000080C0E000000000000000000000000000000
        0000000000080C16140B000000000000000000000000000000000000080C1014
        10080000000000000000000000000808080808080C12140E0800000000000000
        00000000000808081014161614081008000000000000000000000000080B120E
        0B14161614120800000000000000000000000000000810141008141412120800
        0000000000000000000000000000081418100810121208000000000000000000
        0000000000000008141410081012080000000000000000000000001600000000
        0812120E0810080000000000000000040000160E04000000000810120E080800
        000000000000040804160E040016000000000B10120B08000000000000040810
        1408040016100400000000080B080000000000000004040C181808160E040016
        00000000080000000000000000040B0412181004040016100400000000000000
        0000000000040E0E040C0E0804160E0400000000000000000000000000041010
        0B040808080404000000000000000000000000000004100C0B08040408040400
        00000000000000000000000000040C0B08040404040804010000000000000000
        00000000040B040804080404010101000000000000000000000000040B140404
        010101010101000000000000000000000000040E160804010000000000000000
        0000000000000000000008140804010000000000000000000000000000000000
        0000010404010000000000000000000000000000000000000000}
    end
    object Tmensagem: TSpeedButton
      Left = 327
      Top = 27
      Width = 132
      Height = 26
      Caption = 'Thread Mensagem'
      Flat = True
      Glyph.Data = {
        76060000424D7606000000000000360400002800000018000000180000000100
        0800000000004002000000000000000000000001000000010000FF00FF007777
        7700787878007D7D7D008080800086868600888888008D8D8D00919191009494
        9400999999009D9D9D00A1A1A100A6A6A600AAAAAA00ADADAD00B1B1B100B4B4
        B400B9B9B900BEBEBE00C1C1C100C5C5C500CACACA00CCCCCC00D2D2D200D7D7
        D700000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000000000000000000000000000000000000000
        0000000000000000000000000000080C0E000000000000000000000000000000
        0000000000080C16140B000000000000000000000000000000000000080C1014
        10080000000000000000000000000808080808080C12140E0800000000000000
        00000000000808081014161614081008000000000000000000000000080B120E
        0B14161614120800000000000000000000000000000810141008141412120800
        0000000000000000000000000000081418100810121208000000000000000000
        0000000000000008141410081012080000000000000000000000001600000000
        0812120E0810080000000000000000040000160E04000000000810120E080800
        000000000000040804160E040016000000000B10120B08000000000000040810
        1408040016100400000000080B080000000000000004040C181808160E040016
        00000000080000000000000000040B0412181004040016100400000000000000
        0000000000040E0E040C0E0804160E0400000000000000000000000000041010
        0B040808080404000000000000000000000000000004100C0B08040408040400
        00000000000000000000000000040C0B08040404040804010000000000000000
        00000000040B040804080404010101000000000000000000000000040B140404
        010101010101000000000000000000000000040E160804010000000000000000
        0000000000000000000008140804010000000000000000000000000000000000
        0000010404010000000000000000000000000000000000000000}
    end
    object PacotesSeg: TLabel
      Left = 220
      Top = 30
      Width = 6
      Height = 13
      Alignment = taRightJustify
      Caption = '0'
    end
  end
  object DBGrid1: TDBGrid
    Left = 0
    Top = 81
    Width = 462
    Height = 261
    Align = alClient
    DataSource = DataSource1
    TabOrder = 0
    TitleFont.Charset = DEFAULT_CHARSET
    TitleFont.Color = clWindowText
    TitleFont.Height = -11
    TitleFont.Name = 'MS Sans Serif'
    TitleFont.Style = []
    Visible = False
  end
  object TimerGravacao: TTimer
    Enabled = False
    Interval = 2000
    OnTimer = TimerGravacaoTimer
    Left = 176
    Top = 48
  end
  object DataSource1: TDataSource
    Left = 80
    Top = 48
  end
  object TimerOutros: TTimer
    Enabled = False
    Interval = 60000
    OnTimer = TimerOutrosTimer
    Left = 208
    Top = 48
  end
end
