unit thread_query;

interface

uses
   Windows, SysUtils, Classes, Math, DB, DBClient, Types,
   ZConnection, ZDataset, ZAbstractRODataset, ZSqlProcessor,
   DateUtils, FuncColetor, FunAcp;

type

   dbquery = class(TThread)

   public

      // Parametros recebidos
      db_inserts: Integer; // Insert Simultaneo
      db_hostname: String; // Nome do Host
      db_username: String; // Usuario
      db_database: String; // Database
      db_password: String; // Password
      Arq_Log: String;
      Arq_SQL: String;
      DirSql: String;
      DirErrosSql: String;
      Encerrar: Boolean;
      Debug: Integer;
      ThreadId: Word;
      ReciclarSql: Word;

      // Objetos
      QryBatch: TZSqlProcessor; // Um objeto query local
      conn: TZConnection; // Uma tconnection local

   private
      { Private declarations }
      SqlPendente: String;

   protected

      procedure Execute; override;
      Procedure BuscaArquivo;
      Procedure Dormir(pTempo: Word);

   end;

implementation

Uses Gateway_01;

// Execucao da Thread em si.
procedure dbquery.Execute;
begin
   Try
      // CarregaValores;
      conn                 := TZConnection.Create(nil);
      QryBatch             := TZSqlProcessor.Create(Nil);
      conn.HostName        := db_hostname;
      conn.User            := db_username;
      conn.Password        := db_password;
      conn.Database        := db_database;
      conn.Protocol        := 'mysql';
      conn.Port            := 3306;
      QryBatch.Connection  := conn;
      conn.Properties.Add('sort_buffer_size=4096');
      conn.Properties.Add('join_buffer_size=64536');

      ReciclarSql := 0;

      Try
         conn.Connect;
      Except
         SalvaLog(Arq_Log, 'Erro ao conectar com o MySql:(Thread): ' + InttoStr(ThreadId));
      End;

      while Not Encerrar do
      Begin

         // A cada 1000 arquivos processados, reconecta ao banco de dados;
         // Evitar Memory Leak
         if ReciclarSql > 300 then
            try
               Begin
                  conn.Disconnect;
                  conn.Connect;
                  ReciclarSql := 0;
                  SalvaLog(Arq_Log, 'Thread de gravação Reinicializada (' +
                     InttoStr(ThreadId) + ')');
               End;

            Except
               SalvaLog(Arq_Log, 'Erro ao Reciclar Conexão Sql (Thread): ' +
                  InttoStr(ThreadId));
               Dormir(10000);
               Continue;
            end;

         Arq_Log := ExtractFileDir(Arq_Log) + '\' + FormatDateTime('yyyy-mm-dd',
            now) + '.log';

         TcpSrvForm.Thdb_query_Ultimo := now;

         Try
            if (Not conn.PingServer) then
            Begin
               conn.Disconnect;
               conn.Connect;
            End;
         Except
            SalvaLog(Arq_Log, 'Erro ao "pingar" o MySql (Thread): ' +
               InttoStr(ThreadId));
            Dormir(30000);
            Continue;
         End;

         if (Not conn.Connected) then
            Try
               conn.Disconnect;
               conn.Connect;
            Except
               SalvaLog(Arq_Log, 'Erro ao conectar com o MySql (Thread): ' +
                  InttoStr(ThreadId));
               Dormir(30000);
               Continue;
            End;

         BuscaArquivo;

      End;

      conn.Disconnect;
      QryBatch.Free;
      conn.Free;
      Self.Free;

   Except

      SalvaLog(Arq_Log, 'ERRO - Thread Query Generica - Encerrada por Erro: ' +
         InttoStr(ThreadId));
      Encerrar := True;
      Self.Free;

   End;

end;

Procedure dbquery.BuscaArquivo;
Var
   Arquivos: TSearchRec;
Var
   Arq_SQL: String;
   Arq_Erro: String;

Begin

   // Checa Se existe arquivo de Sql Pendente e tenta gravar....

   Arq_SQL := '';

   if FindFirst(DirSql + '\*.???' + FormatFloat('00', ThreadId), faArchive,
      Arquivos) = 0 then
   begin
      Arq_SQL  := DirSql + '\' + Arquivos.Name;
      Arq_Erro := DirErrosSql + '\' + Arquivos.Name;
   End;

   FindClose(Arquivos);

   If Arq_SQL <> '' Then
   Begin

      try

         SqlPendente := CarregaArquivo(Arq_SQL);

         If ExecutarBatch(SqlPendente, Arq_Log, QryBatch) Then
         Begin
            DeleteFile(Arq_SQL);
         End
         Else
         Begin
            SalvaArquivo(Arq_Erro, SqlPendente);
            DeleteFile(Arq_SQL);
         End;

         Inc(ReciclarSql);

      Except
         SalvaArquivo(Arq_Erro, SqlPendente);
         DeleteFile(Arq_SQL);
         SalvaLog(Arq_Log, 'Erro ao processar Sql Pendente:' + Arq_SQL);
      end;

   End;

   Sleep(100);

End;

Procedure dbquery.Dormir(pTempo: Word);
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
