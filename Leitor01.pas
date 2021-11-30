unit Leitor01;

interface

uses Windows, SysUtils, Classes, Graphics, Forms, Controls, Menus,
  StdCtrls, Dialogs, Buttons, Messages, ExtCtrls, ComCtrls, StdActns,
  ActnList, ToolWin, ImgList, Grids, DBGrids, DB, DBClient, DBCtrls,
  StrUtils;

type
  TMainForm = class(TForm)
    OpenDialog1: TOpenDialog;
    Panel1: TPanel;
    BitBtn1: TBitBtn;
    ClientDataSet1: TClientDataSet;
    DataSource1: TDataSource;
    DBGrid1: TDBGrid;
    BitBtn2: TBitBtn;
    DBNavigator1: TDBNavigator;
    Edit1: TEdit;
    Edit2: TEdit;
    BitBtn3: TBitBtn;
    procedure BitBtn1Click(Sender: TObject);
    procedure BitBtn2Click(Sender: TObject);
    Procedure StringProcessar(Var pResto,pProcessa,pSeparador: String);
    procedure BitBtn3Click(Sender: TObject);
    Function  HexToBits(H: String): String;
    function  HexToInt(const HexStr: string): word;
    function  testbiti(v: word; bit: byte): byte;
    Function  HexToStrBitsInverted(pHex: String; pZeroToUm: Boolean ): String;
    Function  hms_to_latitude(pStr:String): Double;
    Function  ParaFloat(pstr: String): Double;
  private
    { Private declarations }
    NomeArquivo : String;
  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

Function TMainForm.ParaFloat(pstr: String): Double;
Begin


Try
  If pstr = 'NA' Then
     Result := 0
  Else If Trim(pstr) = '' Then
     Result := 0
  Else
     Result := StrtoFloat( Trim(ReplaceStr(pstr,'.',',')));
Except
  Result := 0;
End;
End;

Function TMainForm.hms_to_latitude(pStr:String): Double;
Var Negativo  : Double;
    Converter : Double;
Begin

   if Copy(pStr,1,1) = '-' then
   Begin
      Negativo := -1;
      pStr := Copy(pStr,2,200);
   End
   Else if Copy(pStr,1,1) = '+' then
   Begin
      Negativo := 1;
      pStr := Copy(pStr,2,200);
   End;

   pStr := Trim(pStr);

   Try
      Converter := ParaFloat(Copy(pStr,1,2));   //hh
      Converter := Converter + ParaFloat(Copy(pStr,3,2))/60;  //min
      Converter := Converter + ParaFloat(Copy(pStr,5,4))/100 / 3600;  //Segundo
      Result    := Converter * Negativo;
   Except
      Result := 0;
   End;

End;

Function TMainForm.HexToStrBitsInverted(pHex: String; pZeroToUm: Boolean ): String;
Var NumTmp  : Integer;
    Contador: ShortInt;
    lZero:    String;
    lUm:      String;
begin

   if pZeroToUm  then
   Begin
      lZero := '1';
      lUm   := '0';
   End
   Else
   Begin
      lZero := '0';
      lUm   := '1';
   End;

   NumTmp := StrToInt('$'+ pHex);

   for Contador := 0 to 15 do
     if (NumTmp and (1 shl Contador)) = 0 then
        Result := Result + lZero
     Else
        Result := Result + lUm;

end;


function TMainForm.testbiti(v: word; bit: byte): byte;
begin
   Result := byte((v and (1 shl bit)) > 0);
   if Result = 1 then
      Result := 0
   else
      Result := 1;
end;

function TMainForm.HexToInt(const HexStr: string): word;
var
   iNdx: integer;
   cTmp: Char;
begin
   result := 0;
   for iNdx := 1 to Length(HexStr) do
      begin
         cTmp := HexStr[iNdx];
         case cTmp of
            '0'..'9': Result := 16 * Result + (Ord(cTmp) - $30);
            'A'..'F': Result := 16 * Result + (Ord(cTmp) - $37);
            'a'..'f': Result := 16 * Result + (Ord(cTmp) - $57);
        end;
     end;
end;

Function TMainForm.HexToBits(H: String): String;
Var NumTmp  : Integer;
    Contador: ShortInt;
begin

   NumTmp := StrToInt('$'+ H);

   for Contador := 0 to 15 do
     if (NumTmp and (1 shl Contador)) <> 0 then
        Result := '1' + Result
     Else
        Result := '0' + Result;

end;

Procedure TMainForm.StringProcessar(Var pResto,pProcessa,pSeparador: String);
Var Posicao: SmallInt;
Begin

   Posicao := Pos(pseparador,pResto);
   if (Posicao = 0) and (Length(pResto) > 0) then
   Begin
      pResto    := '';
      pProcessa := pResto;
   End
   Else
   Begin
      pProcessa := Copy(pResto,1,Posicao-1);
      pResto    := Copy(pResto,Posicao + 1,2000);
   End;

End;

procedure TMainForm.BitBtn1Click(Sender: TObject);
begin
NomeArquivo := '' ;

OpenDialog1.InitialDir := ExtractFileDir(application.ExeName);

if Not OpenDialog1.Execute then
   Exit;

NomeArquivo := OpenDialog1.FileName;
ClientDataSet1.Close;
ClientDataSet1.FieldDefs.Clear;
ClientDataSet1.FieldDefs.Add('Tcp_Client', ftInteger, 0, False);
ClientDataSet1.FieldDefs.Add('IP', ftString, 15, False);
ClientDataSet1.FieldDefs.Add('Porta', ftInteger, 0, False);
ClientDataSet1.FieldDefs.Add('ID', ftString, 20, False);
ClientDataSet1.FieldDefs.Add('MsgSequencia', ftInteger, 0, False);
ClientDataSet1.FieldDefs.Add('Datagrama', ftString, 1540, False);
ClientDataSet1.CreateDataset;
ClientDataSet1.LoadFromFile(NomeArquivo);

ShowMessage('Registros: '+ IntToStr(ClientDataSet1.RecordCount));

end;

procedure TMainForm.BitBtn2Click(Sender: TObject);
begin
ClientDataSet1.SaveToFile(NomeArquivo);
end;

procedure TMainForm.BitBtn3Click(Sender: TObject);
Var lResto, lProcessa,lSeparador: String;
    Numero: Integer;
begin
{
lSeparador := ',';
lResto     := Edit1.Text;
lProcessa  := Edit2.Text;
StringProcessar(lResto,lProcessa,lSeparador);
Edit1.Text := lResto;
Edit2.Text := lProcessa;
}

{
Edit2.Text := HexToBits(edit1.Text);
}

Numero := HexToInt(Edit1.Text);
Edit2.Text := IntToStr(testbiti(Numero,0)) +
              IntToStr(testbiti(Numero,1)) +
              IntToStr(testbiti(Numero,2)) +
              IntToStr(testbiti(Numero,3)) +
              IntToStr(testbiti(Numero,4)) +
              IntToStr(testbiti(Numero,5)) +
              IntToStr(testbiti(Numero,6)) +
              IntToStr(testbiti(Numero,7)) +
              IntToStr(testbiti(Numero,8)) +
              IntToStr(testbiti(Numero,9)) +
              IntToStr(testbiti(Numero,10)) +
              IntToStr(testbiti(Numero,11)) +
              IntToStr(testbiti(Numero,12)) +
              IntToStr(testbiti(Numero,13)) +
              IntToStr(testbiti(Numero,14)) +
              IntToStr(testbiti(Numero,15)) + ' - ' +
              HexToStrBitsInverted(Edit1.Text,False);


{
Edit2.Text := FloatToStr(hms_to_latitude(Edit1.Text));
}
end;

end.
