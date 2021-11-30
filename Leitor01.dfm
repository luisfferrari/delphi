object MainForm: TMainForm
  Left = 194
  Top = 111
  Caption = 'Leitor de Pacotes Recebidos'
  ClientHeight = 328
  ClientWidth = 571
  Color = clAppWorkSpace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clBlack
  Font.Height = -11
  Font.Name = 'Default'
  Font.Style = []
  FormStyle = fsMDIForm
  OldCreateOrder = False
  Position = poDefault
  PixelsPerInch = 96
  TextHeight = 13
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 571
    Height = 97
    Align = alTop
    TabOrder = 0
    object BitBtn1: TBitBtn
      Left = 16
      Top = 9
      Width = 75
      Height = 25
      Caption = 'Abrir Arquivo'
      DoubleBuffered = True
      ParentDoubleBuffered = False
      TabOrder = 0
      OnClick = BitBtn1Click
    end
    object BitBtn2: TBitBtn
      Left = 112
      Top = 9
      Width = 75
      Height = 25
      Caption = 'Salvar Arquivo'
      DoubleBuffered = True
      ParentDoubleBuffered = False
      TabOrder = 1
      OnClick = BitBtn2Click
    end
    object Edit1: TEdit
      Left = 8
      Top = 40
      Width = 545
      Height = 21
      TabOrder = 2
    end
    object Edit2: TEdit
      Left = 8
      Top = 67
      Width = 545
      Height = 21
      TabOrder = 3
    end
    object BitBtn3: TBitBtn
      Left = 208
      Top = 9
      Width = 75
      Height = 25
      Caption = 'Processar Str'
      DoubleBuffered = True
      ParentDoubleBuffered = False
      TabOrder = 4
      OnClick = BitBtn3Click
    end
  end
  object DBGrid1: TDBGrid
    Left = 0
    Top = 97
    Width = 571
    Height = 231
    Align = alClient
    DataSource = DataSource1
    TabOrder = 1
    TitleFont.Charset = DEFAULT_CHARSET
    TitleFont.Color = clBlack
    TitleFont.Height = -11
    TitleFont.Name = 'Default'
    TitleFont.Style = []
  end
  object DBNavigator1: TDBNavigator
    Left = 331
    Top = 16
    Width = 240
    Height = 25
    DataSource = DataSource1
    TabOrder = 2
  end
  object OpenDialog1: TOpenDialog
    FileName = '*.rec'
    Filter = 
      'Arquivos WebTech|*.Web|Arquivos ACP|*.acp|Arquivos Satlight|*.Sa' +
      't'
    Options = [ofHideReadOnly, ofPathMustExist, ofFileMustExist, ofEnableSizing]
    Left = 296
    Top = 136
  end
  object ClientDataSet1: TClientDataSet
    Aggregates = <>
    Params = <>
    Left = 416
    Top = 144
  end
  object DataSource1: TDataSource
    DataSet = ClientDataSet1
    Left = 480
    Top = 144
  end
end
