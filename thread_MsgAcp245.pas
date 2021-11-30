unit thread_MsgAcp245;

interface

uses
   Windows, SysUtils, Classes, DB, DBClient, Types,
   ZConnection, ZAbstractRODataset, ZDataset,
   FuncColetor, FunAcp;

type

   MsgAcp245 = class(TThread)

   public

      // Parametros recebidos
      db_hostname: String; // Nome do Host
      db_username: String; // Usuario
      db_database: String; // Database
      db_password: String; // Password
      cpr_db_hostname: String; // Nome do Host
      cpr_db_username: String; // Usuario
      cpr_db_database: String; // Database
      cpr_db_password: String; // Password
      DirMens: String;
      Arq_Log: String;
      PortaLocal: String;
      Debug: Integer;
      Debug_ID: String;
      Encerrar: Boolean;
      Srv_Equipo: String; // Nome do protocolo a escutar / processar

      // Objetos
      Qry: TZReadOnlyQuery; // Um objeto query local
      // Qry_cpr     : TZReadOnlyQuery; //Um objeto query local
      conn: TZConnection; // Uma tconnection local
      // conn_cpr    : TZConnection;    //Uma tconnection local

   private
      { Private declarations }
      Mensagens: TClientDataset;
      Resposta: TByteDynArray;
      PacketStr: String;

   protected

      procedure Execute; override;
      Procedure BuscaMensagem;
      Procedure EnviaMensagem;
      Procedure AtualizaEnvio;
      Function Encode(pComando: String): Boolean;
      Procedure Dormir(pTempo: Word);

   end;

implementation

Uses Gateway_01;

// Execucao da Thread em si.
procedure MsgAcp245.Execute;
begin

   Try

      // CarregaValores;
      conn := TZConnection.Create(nil);
      // Conn_cpr             := TZConnection.Create(nil);
      Qry := TZReadOnlyQuery.Create(nil);
      // Qry_cpr              := TZReadOnlyQuery.Create(nil);

      conn.Properties.Add('compress=1');
      conn.Properties.Add('sort_buffer_size=4096');
      conn.Properties.Add('join_buffer_size=4096');

      conn.HostName := db_hostname;
      conn.User := db_username;
      conn.Password := db_password;
      conn.Database := db_database;
      conn.Protocol := 'mysql';
      conn.Port := 3306;
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
      Mensagens.FieldDefs.Add('Comando', ftBlob, 0, False);
      Mensagens.FieldDefs.Add('Status', ftInteger, 0, False);
      Mensagens.FieldDefs.Add('Origem', ftInteger, 0, False);
      Mensagens.CreateDataset;

      while Not Encerrar do
      Begin

         TcpSrvForm.ThMsgAcp245_ultimo := Now;

         Try
            if Not conn.PingServer then
            Begin
               conn.Disconnect;
               conn.Connect;
            End;
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

      Encerrar := True;
      Qry.Close;
      conn.Disconnect;
      Qry.Free;
      conn.Free;
      Self.Free;

   Except

      SalvaLog(Arq_Log, 'ERRO - Thread Mensagem ACP245 - Encerrada por Erro: ' +
         InttoStr(ThreadId));

      Encerrar := True;
      Self.Free;

   End;

end;

Procedure MsgAcp245.BuscaMensagem;
Var
   blobR: TBlobField;
   StreamRes: TMemoryStream;
//   Contador: Word;
Begin
   { Exemplo
     <CONTROL_ENTITY;128;1;0;60>
   }

   Mensagens.EmptyDataSet;

   try

      Qry.Close;
      Qry.Sql.Clear;
      Qry.Sql.Add
         ('Select  cmd.id, cmd.Sequencia, cmd.comando, acp.Car_manufacturer, acp.TCU_Manufacturer, acp.Major_HardWare_Release, acp.Major_SoftWare_Release, acp.Tcu_Serial');
      Qry.Sql.Add('from nexsat.comandos_envio cmd ');
      Qry.Sql.Add('Inner Join nexsat.acp245_data acp ');
      Qry.Sql.Add('on acp.id = cmd.id ');
      Qry.Sql.Add('Where cmd.porta = ' + PortaLocal + ' and status = 0;');
      Qry.Open;

      while Not Qry.Eof do
      Begin

         if Encode(Qry.FieldByName('comando').AsString) then
         Begin

            if (Debug in [4, 5, 9]) or
               (Debug_ID = Qry.FieldByName('ID').AsString) then
               SalvaLog(Arq_Log, 'Tamanho do Pacote de envio: (1)' +
                  InttoStr(Length(Resposta)));

            Mensagens.Append;
            Mensagens.FieldByName('ID').AsString :=
               Qry.FieldByName('ID').AsString;
            Mensagens.FieldByName('Sequencia').AsInteger :=
               Qry.FieldByName('Sequencia').AsInteger;
            Mensagens.FieldByName('Status').AsInteger := 0;
            Mensagens.FieldByName('Origem').AsInteger := 0; // MultiGateway

            StreamRes := TMemoryStream.Create;
            ByteArrayToStream(Resposta, StreamRes);
            blobR := Mensagens.FieldByName('Comando') as TBlobField;
            Try
               try
                  blobR.LoadFromStream(StreamRes);
               finally
                  StreamRes.Free;
               end;
            Except
               SalvaLog(Arq_Log, 'Erro ao Salvar o TBlobField-Resposta: ');
            End;

            Mensagens.Post;

            if Debug in [4, 5, 9] then
               SalvaLog(Arq_Log, 'Tamanho do Pacote de envio: (2)' +
                  InttoStr(Length(Resposta)));

         End;
         Qry.Next;
      End;

      {
        Qry_cpr.Close;
        Qry_cpr.Sql.Clear;
        Qry_cpr.SQL.Add('Select id_tca, id_msg, datagrama ');
        Qry_cpr.SQL.Add('from tcp.cpr_outbox ');
        Qry_cpr.SQL.Add('where id_status = 1 ');
        Qry_cpr.SQL.Add('Order by dt_outbox desc');
        Qry_cpr.Open;

        while Not Qry.Eof do
        Begin

        Mensagens.Append;
        Mensagens.FieldByName('ID').AsString := Mensagens.FieldByName('id_tca').AsString;
        Mensagens.FieldByName('Sequencia').AsInteger := Mensagens.FieldByName('id_msg').AsInteger;
        Mensagens.FieldByName('Status').AsInteger := 0;
        Mensagens.FieldByName('Origem').AsInteger := 1; //CPR

        SetLength(Resposta, 0);
        Contador := 1;
        While Contador  <= Length(Mensagens.FieldByName('datagrama').AsString) do
        Begin
        SetLength(Resposta, Length(Resposta) + 1);
        Resposta[Contador] := StrtoInt( '$' + Copy(Mensagens.FieldByName('datagrama').AsString,Contador,2));
        Contador := Contador + 2;
        End;
        StreamRes                                     := TMemoryStream.Create;
        ByteArrayToStream(Resposta,StreamRes);
        blobR                                         := Mensagens.FieldByName('datagrama') as TBlobField;
        Try
        try
        blobr.LoadFromStream(StreamRes);
        finally
        StreamRes.Free;
        end;
        Except
        SalvaLog(Arq_Log,'Erro ao Salvar o TBlobField-Resposta: ' );
        End;

        Mensagens.Post;

        if Debug in [4,5,9]  then
        SalvaLog(Arq_Log,'Tamanho do Pacote de envio: (2)' + InttoStr(Length(Resposta)));

        Qry.Next;

        End;
      }
      If (Debug in [4, 5, 9]) and (Mensagens.RecordCount > 0) Then
         SalvaLog(Arq_Log, 'Numero de mensagens lidas a enviar:  ' +
            InttoStr(Mensagens.RecordCount));

   Except
      SalvaLog(Arq_Log, 'Erro ao ler mensagens no Banco de dados: ');
   end;

   Sleep(50);

End;

Procedure MsgAcp245.EnviaMensagem;

Begin

   Try

      If Not TcpSrvForm.EnviaMsgAcp245(Mensagens) Then
         SalvaLog(Arq_Log, InttoStr(Mensagens.RecordCount) +
            ' Mensagens Não Enviadas desconectado ? ');
      // If Debug in [4,5,9] Then

   Except
      SalvaLog(Arq_Log, 'Erro ao Enviar Mensagens: ');
   End;

End;

Procedure MsgAcp245.AtualizaEnvio;
Var
   SqlExec: String;
Begin

   Mensagens.First;

   while Not Mensagens.Eof do
      try

         If (Mensagens.FieldByName('ORIGEM').AsInteger = 0) and // MultiGateway
            (Mensagens.FieldByName('Status').AsInteger = 3) Then
         Begin

            SqlExec := 'Update nexsat.comandos_envio Set Status = 1' +
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
         { Else If (Mensagens.FieldByName('ORIGEM').Asinteger = 1) and //CPR
           (Mensagens.FieldByName('Status').Asinteger = 3) Then
           Begin

           SqlExec := 'Update tcp.cpr_outbox Set id_status = 3' +
           ' Where id_tca = ' + QuotedStr(Mensagens.FieldByName('Id').AsString) +
           ' and id_msg = ' + Mensagens.FieldByName('Sequencia').AsString +
           ' and id_status = 1;' + Char(13) + Char(10);

           if ExecutarSql(SqlExec, Arq_Log, Qry_cpr) Then
           Begin
           if Debug in [4,5,9]  then
           SalvaLog(Arq_Log,'Salvo no Banco o Envio: (ID/Sequencia): (' + Mensagens.FieldByName('ID').AsString + ':' + Mensagens.FieldByName('Sequencia').AsString + ')');
           Mensagens.Delete;
           End
           Else
           Begin
           SalvaLog(Arq_Log,'Não achou no Banco a Mensagem enviada: (ID/Sequencia): (' + Mensagens.FieldByName('ID').AsString + ':' + Mensagens.FieldByName('Sequencia').AsString + ')');
           Mensagens.Next;
           End;

           End
         } Else
            Mensagens.Next;

      Except

         SalvaLog(Arq_Log, 'Erro ao Atualizar mensagens enviadas: ');

      end;

End;

Function MsgAcp245.Encode(pComando: String): Boolean;
Var
   StrTmp: String;
   StrTmp2: String;
   Comando: tCmdAcp245;
   Contador: Word;
   Tamanho: Word;
   TmpBytes: TBytes;
Begin

   {
     Exemplo:
     6,3,32,36,      -- Header
     4,64,135,1,8,   -- Version
     3,128,0,255,    -- Control
     1,3,            -- Function
     1,0,            -- Error
     18,144,32,4,0,0,12,186,138,137,85,2,128,0,1,84,116,148,80 --Vehicle

   }
   StrTmp := pComando;
   Result := False;
   Tamanho := 0;
   Try

      while Length(StrTmp) > 0 do
      Begin

         Comando := SeparaComandos(StrTmp);
         if Debug in [5, 9] then
            SalvaLog(Arq_Log, 'Comando a ser enviado: ' + pComando);
         // Comando Validado Montar pacote de resposta
         if Comando.OK then
         Begin
            // Pacote tipo 6
            if Comando.Tipo = 'CONTROL_ENTITY' then
            Begin
               SetLength(Resposta, 100);
               // Header
               // 1 Byte Application ID
               Resposta[Tamanho] := BintoInt('00' + Copy(IntToStrBin(6), 3, 6));
               Inc(Tamanho);
               // 2 Byte MessageType = (default=0x02)
               Resposta[Tamanho] :=
                  BintoInt('000' + Copy(IntToStrBin(2), 4, 5));
               Inc(Tamanho);
               // 3 Byte Application Version  + Message Control Flag
               Resposta[Tamanho] := BintoInt('00100001');
               Inc(Tamanho);
               // 4 Byte Message length
               Resposta[Tamanho] := 4;
               Inc(Tamanho);

               // Version
               // 1 Byte Version Element - Header (4 = Length of Version Element)
               Resposta[Tamanho] := 4;
               Inc(Tamanho);
               // 1 Byte Version Element - Car Manufacturer ID
               Resposta[Tamanho] := Qry.FieldByName('Car_manufacturer')
                  .AsInteger;
               Inc(Tamanho);
               // 1 Byte Version Element - Car Manufacturer ID
               Resposta[Tamanho] := Qry.FieldByName('TCU_Manufacturer')
                  .AsInteger;
               Inc(Tamanho);
               // 1 Byte Version Element - Major hardware release
               Resposta[Tamanho] := Qry.FieldByName('Major_HardWare_Release')
                  .AsInteger;
               Inc(Tamanho);
               // 1 Byte Version Element - Major hardware release
               Resposta[Tamanho] := Qry.FieldByName('Major_SoftWare_Release')
                  .AsInteger;
               Inc(Tamanho);

               // Control
               // Length of Control
               Resposta[Tamanho] := 3;
               Inc(Tamanho);
               // 1 Byte Entity ID
               Resposta[Tamanho] := Comando.Codigo;
               Inc(Tamanho);
               // 1 Byte Reserved + Transmit Unit
               Resposta[Tamanho] := Comando.UnidadeTempo;
               Inc(Tamanho);
               // 1 Byte Transmit Interval
               Resposta[Tamanho] := Comando.Tempo;
               Inc(Tamanho);

               // Function
               // Length of Function
               Resposta[Tamanho] := 1;
               Inc(Tamanho);
               // 1 Byte Function Command
               Resposta[Tamanho] := Comando.Valor;
               Inc(Tamanho);

               { //Error
                 //Length of Error
                 Resposta[Tamanho] :=  1;
                 Inc(Tamanho);
                 //1 Byte Function Command
                 Resposta[Tamanho] := 0;
                 Inc(Tamanho);
               }
               // Vehicle
               // Length of Vehicle
               Resposta[Tamanho] := 13;
               Inc(Tamanho);
               // 1 Byte Flag 1
               Resposta[Tamanho] := BintoInt('10000000');
               Inc(Tamanho);
               // 1 Byte Flag 2
               Resposta[Tamanho] := BintoInt('00100000');
               Inc(Tamanho);

               { //Vehicle TCU SERIAL
                 Resposta[Tamanho] :=  4;
                 Inc(Tamanho);
                 TmpBytes := IntToBin(Qry.FieldByName('TCU_Serial').AsInteger);
                 Resposta[Tamanho] :=  TmpBytes[0];
                 Inc(Tamanho);
                 Resposta[Tamanho] :=  TmpBytes[1];
                 Inc(Tamanho);
                 Resposta[Tamanho] :=  TmpBytes[2];
                 Inc(Tamanho);
                 Resposta[Tamanho] :=  TmpBytes[3];
                 Inc(Tamanho);
               }
               // SIM CARD ID 10 posicoes
               // Sim Card Header
               Resposta[Tamanho] := BintoInt('10001010');
               Inc(Tamanho);
               StrTmp2 := Qry.FieldByName('ID').AsString;
               TmpBytes := StringtoBCD(StrTmp2, 20);
               for Contador := 0 to Length(TmpBytes) - 1 do
               begin
                  Resposta[Tamanho] := TmpBytes[Contador];
                  Inc(Tamanho);
               end;

               SetLength(Resposta, Tamanho);
               // Tamanho Total do Pacote
               Resposta[3] := Tamanho;
            End

            // Pacote tipo 2 - 8 Update
            Else if (Comando.Tipo = 'UPDATE_PARAMETER') or
               (Comando.Tipo = 'REQUEST_PARAMETER') then
            Begin
               SetLength(Resposta, 150);
               // Header
               // 1 Byte Application ID
               Resposta[Tamanho] := BintoInt('00' + Copy(IntToStrBin(2), 3, 6));
               Inc(Tamanho);
               // 2 Byte MessageType = (default=0x08)
               Resposta[Tamanho] :=
                  BintoInt('000' + Copy(IntToStrBin(8), 4, 5));
               Inc(Tamanho);
               // 3 Byte Application Version  + Message Control Flag
               Resposta[Tamanho] := BintoInt('00100001');
               Inc(Tamanho);
               // 4 Byte Message length
               Resposta[Tamanho] := 4;
               Inc(Tamanho);

               // Version
               // 1 Byte Version Element - Header (4 = Length of Version Element)
               Resposta[Tamanho] := 4;
               Inc(Tamanho);
               // 1 Byte Version Element - Car Manufacturer ID
               Resposta[Tamanho] := Qry.FieldByName('Car_manufacturer')
                  .AsInteger;
               Inc(Tamanho);
               // 1 Byte Version Element - Car Manufacturer ID
               Resposta[Tamanho] := Qry.FieldByName('TCU_Manufacturer')
                  .AsInteger;
               Inc(Tamanho);
               // 1 Byte Version Element - Major hardware release
               Resposta[Tamanho] := Qry.FieldByName('Major_HardWare_Release')
                  .AsInteger;
               Inc(Tamanho);
               // 1 Byte Version Element - Major hardware release
               Resposta[Tamanho] := Qry.FieldByName('Major_SoftWare_Release')
                  .AsInteger;
               Inc(Tamanho);

               // Message Fields
               // More Flag & Target Application ID = 0
               Resposta[Tamanho] := BintoInt('000' + '00000');
               Inc(Tamanho);
               // ApplFlag1 & ControlFlag1
               If Comando.Tipo = 'UPDATE_PARAMETER' Then
                  Resposta[Tamanho] := BintoInt('11' + '000010')
               Else // Comando.Tipo = 'REQUEST_PARAMETER'
                  Resposta[Tamanho] := BintoInt('00' + '000010');
               Inc(Tamanho);
               // ControlFlag2 Setado acima como ausente
               // Resposta[Tamanho] := BintoInt('00000000' );
               // Inc(Tamanho);
               // Reserved
               Resposta[Tamanho] := 0;
               Inc(Tamanho);

               // Vehicle Descriptor
               // Length of Vehicle
               Resposta[Tamanho] := 13;
               Inc(Tamanho);
               // 1 Byte Flag 1
               Resposta[Tamanho] := BintoInt('10000000');
               Inc(Tamanho);
               // 1 Byte Flag 2
               Resposta[Tamanho] := BintoInt('00100000');
               Inc(Tamanho);
               // SIM CARD ID 10 posicoes
               // Sim Card Header
               Resposta[Tamanho] := BintoInt('10001010');
               Inc(Tamanho);

               StrTmp2 := Qry.FieldByName('ID').AsString;
               TmpBytes := StringtoBCD(StrTmp2, 20);
               for Contador := 0 to Length(TmpBytes) - 1 do
               begin
                  Resposta[Tamanho] := TmpBytes[Contador];
                  Inc(Tamanho);
               end;

               // TCU Descriptor
               // IE_identifier & more_flag & length
               Resposta[Tamanho] := 0;
               Inc(Tamanho);
               // Reserved
               // Resposta[Tamanho] :=  0;
               // Inc(Tamanho);
               // IE_identifier & more_flag & length
               // Resposta[Tamanho] :=  BintoInt('00000001');
               // Inc(Tamanho);
               // Device ID
               // Resposta[Tamanho] :=  BintoInt('00000011');
               // Inc(Tamanho);
               // IE_identifier & more_flag & length
               // Resposta[Tamanho] :=  BintoInt('00000001');
               // Inc(Tamanho);
               // Version ID
               // Resposta[Tamanho] :=  BintoInt('00000001');
               // Inc(Tamanho);

               // TCU Data
               // IE_identifier & more_flag & length
               Resposta[Tamanho] := BintoInt('00000100');
               Inc(Tamanho);
               // Data Type MSB
               StrTmp2 := inttohex(Comando.Codigo, 4);
               Resposta[Tamanho] := ParaInteiro('$' + Copy(StrTmp2, 1, 2));
               Inc(Tamanho);
               // Data Type LSB
               Resposta[Tamanho] := ParaInteiro('$' + Copy(StrTmp2, 3, 2));
               Inc(Tamanho);
               // Length Data
               Resposta[Tamanho] := 1;
               Inc(Tamanho);
               // Configuration Data
               Resposta[Tamanho] := Comando.Valor;
               Inc(Tamanho);

               SetLength(Resposta, Tamanho);
               // Tamanho Total do Pacote
               Resposta[3] := Tamanho;
            End;

            PacketStr := '';
            for Contador := 0 to Length(Resposta) - 1 do
               PacketStr := PacketStr + inttohex(Resposta[Contador], 2);
            if Debug in [4, 5, 9] then
               SalvaLog(Arq_Log, 'Pacote a ser enviado: ' + PacketStr);

         End;

      End;
      Result := True;
   Except
      SalvaLog(Arq_Log, 'Erro no Encode da Mensagem: ' + pComando);

   End;
End;

Procedure MsgAcp245.Dormir(pTempo: Word);
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
