unit thread_msgquanta;

interface

uses
   Windows, SysUtils, Classes, DB, DBClient, ZConnection, ZDataset,
   ZAbstractRODataset, FuncColetor, FunQuanta, Types, FunAcp;

type

   msgQuanta = class(TThread)

   public

      // Parametros recebidos
      db_hostname: String; // Nome do Host
      db_username: String; // Usuario
      db_database: String; // Database
      db_password: String; // Password
      DirMens: String;
      Arq_Log: String;
      ArqMens: String;
      PortaLocal: String;
      Debug_ID: String;
      Debug: Integer;
      Encerrar: Boolean;
      Srv_Equipo: String; // Nome do protocolo a escutar / processar

      // Objetos
      Qry: TZReadOnlyQuery; // Um objeto query local
      conn: TZConnection; // Uma tconnection local

      Arq_mens: String;
      Mensagens: TClientDataset;
      Resposta: TByteDynArray;

   private
      { Private declarations }
   protected

//      WSocketUdpEnv: TWSocket;

      Function Encode(pComando: String): Boolean;
      procedure Execute; override;
      Procedure BuscaMensagem;
      Procedure EnviaMensagem;
      Procedure AtualizaEnvio;
      Function  Encode_31_56_01(pParam: String): Boolean;
      Function  Encode_31_9D_00(pParam: String): Boolean;
      Function  Encode_31_60_00(pParam: String): Boolean;
      Function  Encode_31_9D_01(pParam: String): Boolean;
      Function  Encode_99_63_00(pParam: String): Boolean;
      Procedure Dormir(pTempo: Word);
   end;

implementation

Uses Gateway_01;

// Execucao da Thread em si.
procedure msgQuanta.Execute;
begin

   Try

      conn := TZConnection.Create(nil);
      Qry  := TZReadOnlyQuery.Create(nil);

      conn.Properties.Add('compress=1');
      conn.Properties.Add('sort_buffer_size=4096');
      conn.Properties.Add('join_buffer_size=64536');

      conn.HostName  := db_hostname;
      conn.User      := db_username;
      conn.Password  := db_password;
      conn.Database  := db_database;
      conn.Protocol  := 'mysql';
      conn.Port      := 3306;
      Qry.Connection := conn;

      Try
         conn.Connect;
      Except
         SalvaLog(Arq_Log,
            'Thread LerMensagem - Erro ao conectar com o MySql: ');
      End;

      Mensagens := TClientDataset.Create(nil);
      Mensagens.FieldDefs.Add('ID', ftString, 20, False);
      Mensagens.FieldDefs.Add('Sequencia', ftInteger, 0, False);
      Mensagens.FieldDefs.Add('Comando', ftString, 200, False);
      Mensagens.FieldDefs.Add('Status', ftInteger, 0, False);
      Mensagens.FieldDefs.Add('Origem', ftInteger, 0, False);
      Mensagens.CreateDataset;

      while Not Encerrar do
      Begin

         TcpSrvForm.ThMsgQuanta_ultimo := Now;

         if Not conn.PingServer then
            Try
               conn.Disconnect;
               conn.Connect;
            Except
               SalvaLog(Arq_Log,
                  'Thread LerMensagem - Erro ao "pingar" o MySql: ');
               Dormir(30000);
               Continue;
            End;

         if Not conn.Connected then
            Try
               conn.Disconnect;
               conn.Connect;
            Except
               SalvaLog(Arq_Log,
                  'Thread LerMensagem - Erro ao Conectar com o MySql: ');
               Dormir(30000);
               Continue;
            End;

         BuscaMensagem;

         if (Mensagens.RecordCount > 0) then
         Begin
            Synchronize(EnviaMensagem);
            AtualizaEnvio;
         End;

         Dormir(10000);

      End;

      //SalvaLog(Arq_Log,'Thread Ler Mensagem - Encerrada' );
      //WSocketUdpEnv.Release;

      Encerrar := True;
      Qry.Close;
      conn.Disconnect;
      Qry.Free;
      conn.Free;
      Self.Free;

   Except

      SalvaLog(Arq_Log, 'ERRO - Thread Mensagem Quanta - Encerrada por Erro: '
         + InttoStr(ThreadId));
      Encerrar := True;
      Self.Free;

   End;

end;

Procedure msgQuanta.BuscaMensagem;
Var
   IDStrHex,
   TimeStampStr,
   Comando: String;
   Contador: integer;
Begin

   Mensagens.EmptyDataSet;

   try

      Qry.Close;
      Qry.Sql.Clear;
      Qry.Sql.Add('Select msg.*, pos.ip_remoto, pos.porta_remoto, pos.produto, pos.versao ');
      Qry.Sql.Add('from nexsat.comandos_envio msg ');
      Qry.Sql.Add('Inner Join nexsat.posicoes_lidas pos ');
      Qry.Sql.Add(' on msg.id = pos.id ');
      Qry.Sql.Add('Where msg.porta = ' + PortaLocal + ' and msg.status = 0');
      Qry.Open;

      while Not Qry.Eof do
      Begin

         //SalvaLog(Arq_Log,'ID com mensagem: ' + Qry.FieldByName('ID').AsString);

         IDStrHex     := InttoHex(Qry.FieldByName('ID').AsInteger,8);
         TimeStampStr := InttoHex( DateTimeToTimeStamp(now),8);

         SetLength(Resposta, 13);

         Resposta[0]  := Qry.FieldByName('produto').AsInteger;
         Resposta[1]  := Qry.FieldByName('versao').AsInteger;
         Resposta[2]  := StrToInt('$'+ Copy(IDStrHex,1,2));
         Resposta[3]  := StrToInt('$'+ Copy(IDStrHex,3,2));
         Resposta[4]  := StrToInt('$'+ Copy(IDStrHex,5,2));
         Resposta[5]  := StrToInt('$'+ Copy(IDStrHex,7,2));
         Resposta[6]  := 0;
         Resposta[7]  := StrToInt('$'+ Copy(TimeStampStr,1,2));
         Resposta[8]  := StrToInt('$'+ Copy(TimeStampStr,3,2));
         Resposta[9]  := StrToInt('$'+ Copy(TimeStampStr,5,2));
         Resposta[10] := StrToInt('$'+ Copy(TimeStampStr,7,2));

         //Codifica a mensagem
         If Encode(Qry.FieldByName('COMANDO').AsString) Then
         Begin

            Comando := '';

            for Contador  := 0 to Length(Resposta) - 1 do
               Comando := Comando + IntToHex(Resposta[Contador], 2);

            Mensagens.Append;
            Mensagens.FieldByName('ID').AsString         := Qry.FieldByName('ID').AsString;
            Mensagens.FieldByName('Sequencia').AsInteger := Qry.FieldByName('Sequencia').AsInteger;
            Mensagens.FieldByName('Status').AsInteger    := 0;
            Mensagens.FieldByName('Comando').AsString    := Comando;

            Mensagens.Post;

            if (Debug_ID = Qry.FieldByName('ID').AsString) then
               SalvaLog(Arq_Log, 'ID/Mensagem a Enviar: ' + Qry.FieldByName('ID').AsString + ' / ' + '(' + Comando + ')');

         End
         Else
         Begin

            SalvaLog(Arq_Log, 'Erro Ao Gerar o ENCODE do Comando id: ' + Qry.FieldByName('ID').AsString);

            Comando := '';

            for Contador  := 0 to Length(Resposta) - 1 do
               Comando := Comando + IntToHex(Resposta[Contador], 2) + ':';

            SalvaLog(Arq_Log, 'Encode gerado com erro: ' + Comando);

         End;

         Qry.Next;

      End;

      If (Debug in [4, 5, 9]) and (Mensagens.RecordCount > 0) Then
         SalvaLog(Arq_Log, 'Numero de mensagens lidas a enviar:  ' +
            InttoStr(Mensagens.RecordCount));

   Except
     on E : Exception do
      SalvaLog(Arq_Log, E.ClassName+' Mensagem: '+E.Message);
   end;

   Sleep(50);

End;

Procedure msgQuanta.EnviaMensagem;

Begin

   Try

      If Not TcpSrvForm.EnviaMsgQuanta(Mensagens) Then
         If Debug in [4, 5, 9] Then
            SalvaLog(Arq_Log, InttoStr(Mensagens.RecordCount) +
               ' Mensagens Não Enviadas desconectado ? ');

   Except
      SalvaLog(Arq_Log, 'Erro ao Enviar Mensagens: ' + ArqMens);
   End;

End;

Procedure msgQuanta.AtualizaEnvio;
Var
   SqlExec: String;
Begin
Try
   Mensagens.First;

   while Not Mensagens.Eof do
      try

         If Mensagens.FieldByName('Status').AsInteger = 3 Then
         Begin

            SqlExec := 'Update Nexsat.comandos_envio Set Status = 1' +
               ' Where id = ' + QuotedStr(Mensagens.FieldByName('Id').AsString)
               + ' and Sequencia = ' + Mensagens.FieldByName('Sequencia')
               .AsString + ' and Status = 0;' + Char(13) + Char(10);

            if ExecutarSql(SqlExec, Arq_Log, Qry) Then
            Begin
               if Debug in [4, 5, 9] then
                  SalvaLog(Arq_Log, 'Salvo no Banco o Envio: (ID/Sequencia): ('
                     + Mensagens.FieldByName('ID').AsString + ':' +
                     Mensagens.FieldByName('Sequencia').AsString + ')');
               Mensagens.Delete;
            End
            Else
            Begin
               SalvaLog(Arq_Log,
                  'Não achou no Banco a Mensagem enviada: (ID/Sequencia): (' +
                  Mensagens.FieldByName('ID').AsString + ':' +
                  Mensagens.FieldByName('Sequencia').AsString + ')');
               Mensagens.Next;
            End;

         End
         Else
            Mensagens.Next;

      Except

         SalvaLog(Arq_Log, 'Erro ao Atualizar mensagens enviadas: ');

      end;
Except
   SalvaLog(Arq_Log, 'Erro no Loop: AtualizaEnvio ');
End;
End;

Function msgQuanta.Encode(pComando: String): Boolean;
Var
    Comandos: tquanta_cmd;
Begin

Result := False;

try

{
exemplo
<0x56;56;13;3600|128|0|0|1|4>
}

   //Primeiro separa os parametros em um vetor
   Comandos := SeparaComandosQuanta(pComando);

   Resposta[11] := Comandos.Cmd_id;

   if (Not Comandos.OK) then
   Begin
      SalvaLog(Arq_Log,'Comandos.Ok = False !!!!!!' );
      Exit;
   End
   //Produto 31, mensagem 56, Tipo 1 -
   Else if (Resposta[0] = $31) and  (Comandos.Cmd_id = $56) and (Comandos.Cmd_Param = $01) Then
   Begin
      If Not Encode_31_56_01(Comandos.Params) Then
      Begin
         SalvaLog(Arq_Log, 'Erro ao Gerar o Encode: ');
      End
      else
         Result := True;
   End
   //Produto 31, mensagem 9D, Tipo 0 - Tabela de Tracking
   Else if (Resposta[0] = $31) and (Comandos.Cmd_id = $9D) and (Comandos.Cmd_Param = $00) Then
   Begin
      If Not Encode_31_9D_00(Comandos.Params) Then
      Begin
         SalvaLog(Arq_Log, 'Erro ao Gerar o Encode: ');
      End
      else
         Result := True;
   End
   //Produto 31, mensagem 9D, Tipo 1 - Tabela de Estado
   Else if (Resposta[0] = $31) and (Comandos.Cmd_id = $9D) and (Comandos.Cmd_Param = $1) Then
   Begin
      If Not Encode_31_9D_01(Comandos.Params) Then
      Begin
         SalvaLog(Arq_Log, 'Erro ao Gerar o Encode: ');
      End
      else
         Result := True;
   End
   //Produto 31, mensagem 9D, Tipo 1 - Tabela de Estado
   Else if (Resposta[0] = $31) and (Comandos.Cmd_id = $60) Then
   Begin
      If Not Encode_31_60_00(Comandos.Params) Then
      Begin
         SalvaLog(Arq_Log, 'Erro ao Gerar o Encode: ');
      End
      else
         Result := True;
   End
   //Produto Diferente de 31, mensagem 63 - Tabela de Estado
   Else if (Resposta[0] <> $31) and (Comandos.Cmd_id = $63)  Then
   Begin
      If Not Encode_99_63_00(Comandos.Params) Then
      Begin
         SalvaLog(Arq_Log, 'Erro ao Gerar o Encode: ');
      End
      else
         Result := True;
   End
   Else
   Begin
      SalvaLog(Arq_Log, 'Comando / Parametro não previsto: ' + InttoStr(Comandos.Cmd_id) + '/' + IntToStr(Comandos.Cmd_Param));
   End;

Except
   SalvaLog(Arq_Log, 'Erro ao Gerar o Encode: ');
end;

End;

Function msgQuanta.Encode_31_56_01(pParam: String): Boolean;
Var Contador: Integer;
Var Valores: tquanta_val;
Var CRCCalc: Word;
Var CRCHEX: String;

Begin
Result := False;
try

   SetLength(Resposta, 22);

   //Tamanho  do pacote fixo = 16 + 6
   Resposta[12] := 0;
   Resposta[13] := 22;  //22 Bytes Total

   //0x01 = Identificador Configuração dos Parâmetros das Entradas
   Resposta[14] := 1;

   Valores := SeparaValoresQuanta(pParam);

   //Alteração dos Parâmetros das Entradas - 5 bytes
   for Contador := 0 to 4  do
      if Length(Valores) > Contador  then
         Resposta[15+Contador] := StrToIntDef(Valores[Contador],0)
      Else
         Resposta[15+Contador] := 0;

   CRCCalc      := crc16_ccitt(Resposta, $1021, $ffff, Length(Resposta)-2);
   CRCHEX       := InttoHex(CRCCalc,4);

   //CRC
   Resposta[20] := StrToInt('$'+ Copy(CRCHEX,1,2));
   Resposta[21] := StrToInt('$'+ Copy(CRCHEX,3,2));
   Result := True;

Except
   SalvaLog(Arq_Log, 'Erro ao Gerar o Encode 31_56_01: ' + pParam);
end;
End;

//Solicitacao de Tabela de Tracking
//FIXO !!!
Function msgQuanta.Encode_31_9D_00(pParam: String): Boolean;
Var CRCCalc: Word;
Var CRCHEX: String;

Begin
Result := False;
try

   SetLength(Resposta, 21);  //21 Bytes Total

   //Tamanho  do pacote fixo = 16 + 5
   Resposta[12] := 0;
   Resposta[13] := 21;  //21 Bytes Total

   //0x00 = Solicitacao de Tabela de Tracking
   Resposta[14] := 0; //Tracking

   Resposta[15] := 0;
   Resposta[16] := 1;  //1 Tabela de Tracking
   Resposta[17] := 0;
   Resposta[18] := 0;  //0 Mais recente

   CRCCalc      := crc16_ccitt(Resposta, $1021, $ffff, Length(Resposta)-2);
   CRCHEX       := InttoHex(CRCCalc,4);

   //CRC
   Resposta[19] := StrToInt('$'+ Copy(CRCHEX,1,2));
   Resposta[20] := StrToInt('$'+ Copy(CRCHEX,3,2));
   Result := True;

Except
   SalvaLog(Arq_Log, 'Erro ao Gerar o Encode 31_9D_00: ' + pParam);
end;
End;

//Solicitacao de Tabela de Estados
//FIXO !!!
Function msgQuanta.Encode_31_9D_01(pParam: String): Boolean;
Var CRCCalc: Word;
Var CRCHEX: String;

Begin
Result := False;
try

   SetLength(Resposta, 21);  //21 Bytes Total

   //Tamanho  do pacote fixo = 16 + 5
   Resposta[12] := 0;
   Resposta[13] := 21;  //21 Bytes Total

   //0x00 = Solicitacao de Tabela de Tracking
   Resposta[14] := 0; //0

   Resposta[15] := 0;
   Resposta[16] := 1;  //1 Tabela de Estado
   Resposta[17] := 0;
   Resposta[18] := 0;  //0 Mais recente

   CRCCalc      := crc16_ccitt(Resposta, $1021, $ffff, Length(Resposta)-2);
   CRCHEX       := InttoHex(CRCCalc,4);

   //CRC
   Resposta[19] := StrToInt('$'+ Copy(CRCHEX,1,2));
   Resposta[20] := StrToInt('$'+ Copy(CRCHEX,3,2));
   Result := True;

Except
   SalvaLog(Arq_Log, 'Erro ao Gerar o Encode 31_9D_01: ' + pParam);
end;
End;

//Comandos
Function msgQuanta.Encode_31_60_00(pParam: String): Boolean;
Var CRCCalc: Word;
Var CRCHEX: String;

Begin
Result := False;
try

   SetLength(Resposta, 20);  //20 Bytes Total

   //Tamanho  do pacote fixo = 16 + 4
   Resposta[12] := 0;
   Resposta[13] := 20;  //20 Bytes Total

   //0x02 = Bloqueio
   Resposta[14] := 0; //0
   Resposta[15] := 0;
   Resposta[16] := 0;  //
   Resposta[17] := 2;

   CRCCalc      := crc16_ccitt(Resposta, $1021, $ffff, Length(Resposta)-2);
   CRCHEX       := InttoHex(CRCCalc,4);

   //CRC
   Resposta[18] := StrToInt('$'+ Copy(CRCHEX,1,2));
   Resposta[19] := StrToInt('$'+ Copy(CRCHEX,3,2));
   Result := True;

Except
   SalvaLog(Arq_Log, 'Erro ao Gerar o Encode 31_9D_01: ' + pParam);
end;
End;

//Solicitacao de Tabela de Tracking - Outros Produtos
//FIXO !!!
Function msgQuanta.Encode_99_63_00(pParam: String): Boolean;
Var CRCCalc: Word;
Var CRCHEX: String;

Begin
Result := False;
try

   SetLength(Resposta, 20);  //20 Bytes Total

   //Tamanho  do pacote fixo = 16 + 4
   Resposta[12] := 0;
   Resposta[13] := 20;  //20 Bytes Total

   //0x00 = Solicitacao de Tabela de Tracking
   Resposta[14] := 0;
   Resposta[15] := 1;  //1 Tabela
   Resposta[16] := 0;
   Resposta[17] := 0;  //0 Mais recente

   CRCCalc      := crc16_ccitt(Resposta, $1021, $ffff, Length(Resposta)-2);
   CRCHEX       := InttoHex(CRCCalc,4);

   //CRC
   Resposta[18] := StrToInt('$'+ Copy(CRCHEX,1,2));
   Resposta[19] := StrToInt('$'+ Copy(CRCHEX,3,2));
   Result := True;

Except
   SalvaLog(Arq_Log, 'Erro ao Gerar o Encode 99_63_00: ' + pParam);
end;
End;

Procedure msgQuanta.Dormir(pTempo: Word);
Var
   Contador: Word;
   // Roda o Sleep em slice de 1/20 para checar o Final da thread
Begin
   For Contador := 1 to 20 do
   Begin
      if Not Encerrar then
         Sleep(Trunc(pTempo / 20));
   End
End;

end.
