unit frmMain;

interface

uses
  Windows, SysUtils, Forms, Classes, StdCtrls, Controls, Graphics, ExtCtrls, Winsock, ShellApi, inifiles;

type
  TfMain = class(TForm)
    txIP: TLabel;
    txHost: TLabel;
    txMAC: TLabel;
    Timer1: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  end;

var
  fMain: TfMain;

implementation

{$R *.dfm}

//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// Bilgisayarýn IP Adreslerini Alýr.
function GetIPAddress: Tstrings;
type
  TaPInAddr = array[0..10] of PInAddr;
  PaPInAddr = ^TaPInAddr;
var
  phe: PHostEnt;
  pptr: PaPInAddr;
  Buffer: array[0..63] of AnsiChar;
  I: Integer;
  GInitData: TWSAData;
begin
  WSAStartup($101, GInitData);
  Result := TstringList.Create;
  Result.Clear;
  GetHostName(Buffer, SizeOf(Buffer));
  phe := GetHostByName(buffer);
  if phe = nil then Exit;
  pPtr := PaPInAddr(phe^.h_addr_list);
  I    := 0;
  while pPtr^[I] <> nil do
  begin
    Result.Add(inet_ntoa(pptr^[I]^));
    Inc(I);
  end;
  WSACleanup;
end;
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// Verilen IP adresine ait Bilgisayar adýný bulur
function GetHostNameByIP(const IPAdress: String): String;
var
  SockAddrIn: TSockAddrIn;
  HostEnt: PHostEnt;
  WSAData: TWSAData;
begin
  WSAStartup($101, WSAData);
  SockAddrIn.sin_addr.s_addr := inet_addr(PAnsiChar(IPAdress));
  Application.ProcessMessages;
  HostEnt := gethostbyaddr(@SockAddrIn.sin_addr.S_addr, 4, AF_INET);
  if HostEnt <> nil then
    Result := StrPas(Hostent^.h_name)
  else
    Result := '';
end;
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// Að üzerinde adý verilen bilgisayarýn MAC adresini öðrenir
function GetMacAddress(const AServerName : string) : string;
type
  TNetApiBufferFree = function(Buffer : pointer) : DWORD; stdcall;
  TNetTransportEnum = function(pszServer : PWideChar;
                               Level : DWORD;
                               var pbBuffer : pointer;
                               PrefMaxLen : LongInt;
                               var EntriesRead : DWORD;
                               var TotalEntries : DWORD;
                               var ResumeHandle : DWORD) : DWORD; stdcall;
  PTransportInfo = ^TTransportInfo;
  TTransportInfo = record
                     quality_of_service : DWORD;
                     number_of_vcs      : DWORD;
                     transport_name     : PWChar;
                     transport_address  : PWChar;
                     wan_ish            : Boolean;
                   end;
var
  E, ResumeHandle, EntriesRead, TotalEntries : DWORD;
  sMachineName, sMacAddr, Retvar             : string;
  FLibHandle        : THandle;
  pBuffer           : pointer;
  pInfo             : PTransportInfo;
  FNetTransportEnum : TNetTransportEnum;
  FNetApiBufferFree : TNetApiBufferFree;
  pszServer         : array[0..128] of WideChar;
  i,ii,iIdx         : integer;
begin
  sMachineName := trim(AServerName);
  Retvar := '00-00-00-00-00-00';

  if (sMachineName <> '') and (length(sMachineName) >= 2) then begin
    if copy(sMachineName,1,2) <> '\\' then sMachineName := '\\' + sMachineName
  end;

  pBuffer      := nil;
  ResumeHandle := 0;
  FLibHandle   := LoadLibrary('NETAPI32.DLL');

  if FLibHandle <> 0 then begin
    @FNetTransportEnum := GetProcAddress(FLibHandle,'NetWkstaTransportEnum');
    @FNetApiBufferFree := GetProcAddress(FLibHandle,'NetApiBufferFree');
    E := FNetTransportEnum(StringToWideChar(sMachineName, pszServer, 129), 0, pBuffer, -1, EntriesRead, TotalEntries, Resumehandle);

    if E = 0 then begin
      pInfo := pBuffer;
      for i := 1 to EntriesRead do begin
        if pos('TCPIP',UpperCase(pInfo^.transport_name)) <> 0 then begin
          iIdx := 1;
          sMacAddr := pInfo^.transport_address;
          for ii := 1 to 12 do begin
            Retvar[iIdx] := sMacAddr[ii];
            inc(iIdx);
            if iIdx in [3,6,9,12,15] then inc(iIdx);
          end;
        end;
        inc(pInfo);
      end;
      if pBuffer <> nil then FNetApiBufferFree(pBuffer);
    end;

    try
      FreeLibrary(FLibHandle);
    except
    end;
  end;
  Result := Retvar;
end;
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function GetIP(const HostName: string): string;
var
  WSAData: TWSAData;
  R: PHostEnt;
  A: TInAddr;
begin
  Result := '0.0.0.0';
  WSAStartup($101, WSAData);
  R := Winsock.GetHostByName(PAnsiChar(AnsiString(HostName)));
  if Assigned(R) then
  begin
    A := PInAddr(r^.h_Addr_List^)^;
    Result := WinSock.inet_ntoa(A);
  end;
end;
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure SetTransparent(Aform: TForm; AValue: Boolean);
begin
  Aform.TransparentColor := AValue;
  Aform.TransparentColorValue := Aform.Color;
end;
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure TfMain.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.ExStyle := Params.ExStyle or WS_EX_TOPMOST;
  Params.ExStyle := Params.ExStyle and not WS_EX_APPWINDOW;
  Params.WndParent := Application.Handle;
end;
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure TfMain.FormCreate(Sender: TObject);
var
  HostName     : String;
  RightMargin  : Integer;
  BottomMargin : Integer;
  BackColor    : String;
  FontColor    : String;
  FontSize     : Integer;
  Transparent  : Boolean;
  App          : String;
  Config       : TIniFile;
  IniName      : String;
begin
  IniName := Extractfilepath(application.ExeName) + 'Config.ini';

  Config := Tinifile.Create(IniName);
  if not FileExists(IniName) then begin
    Config.WriteInteger('Config', 'RightMargin' , 0);
    Config.WriteInteger('Config', 'BottomMargin', 0);
    Config.WriteString ('Config', 'BackColor'   , '99B4D1');
    Config.WriteString ('Config', 'FontColor'   , '000000');
    Config.WriteInteger('Config', 'FontSize'    , 16);
    Config.WriteBool   ('Config', 'Transparent' , True);
    Config.WriteString ('Config', 'App'         , 'C:\Windows\System32\Calc.exe');
  end;
  RightMargin  := Config.ReadInteger('Config', 'RightMargin' , 0);
  BottomMargin := Config.ReadInteger('Config', 'BottomMargin', 0);
  BackColor    := Config.ReadString ('Config', 'BackColor'   , '99B4D1');
  FontColor    := Config.ReadString ('Config', 'FontColor'   , '000000');
  FontSize     := Config.ReadInteger('Config', 'FontSize'    , 16);
  Transparent  := Config.ReadBool   ('Config', 'Transparent' , True);
  App          := Config.ReadString ('Config', 'App'         , 'C:\Windows\System32\Calc.exe');
  Config.Free;

  Left := Screen.Width  - Width  - RightMargin;
  Top  := Screen.Height - Height - BottomMargin;

  txIP.Transparent   := Transparent;
  txHost.Transparent := Transparent;
  txMAC.Transparent  := Transparent;

  txIP.Font.Size   := FontSize;
  txHost.Font.Size := FontSize;
  txMAC.Font.Size  := FontSize;

  BackColor    := Copy(BackColor,5,2) + Copy(BackColor,3,2) + Copy(BackColor,1,2);

  Self.Color   := StringToColor('$00'+ BackColor);
  txIP.Color   := StringToColor('$00'+ BackColor);
  txHost.Color := StringToColor('$00'+ BackColor);
  txMAC.Color  := StringToColor('$00'+ BackColor);

  FontColor         := Copy(FontColor,5,2) + Copy(FontColor,3,2) + Copy(FontColor,1,2);
  txIP.Font.Color   := StringToColor('$00'+ FontColor);
  txHost.Font.Color := StringToColor('$00'+ FontColor);
  txMAC.Font.Color  := StringToColor('$00'+ FontColor);

  HostName       := GetEnvironmentVariable('COMPUTERNAME');
  txIP.Caption   := GetIP(HostName); //GetIPAddress[0];
  txHost.Caption := HostName;       //GetHostNameByIP(GetIPAddress[0]);
  txMAC.Caption  := GetMacAddress(HostName);
  SetTransparent(Self, True);

  ShellExecute(0,'open', PChar(App), '', PChar(ExtractFilePath(App)), SW_MAXIMIZE);
end;
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure TfMain.Timer1Timer(Sender: TObject);
begin
  SetWindowPos (Handle, HWND_TOPMOST, 0, 0, 0, 0, SWP_NoMove or SWP_NoSize);
end;

end.
