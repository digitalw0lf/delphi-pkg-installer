program DelphiPkgInstaller;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils, System.IniFiles, System.IOUtils, Winapi.Windows,
  Winapi.ShellAPI, System.Win.Registry;

var
  IniName: string;
  Ini: TMemIniFile;
  Packages, Platforms, Configs: TArray<string>;

function FullPath(const Path: string): string;
var
  Relative: Boolean;
begin
  Result := Path;
  if (Result = '.') or (Result.StartsWith('.' + PathDelim)) then
  begin
    Relative := True;
    Delete(Result, Low(Result), 1);
  end
  else
  if Result.StartsWith('$(Platform)', True) or Result.StartsWith('$(Config)', True) then
  begin
    Relative := True;
  end
  else
  if Result.StartsWith('$(') then   // e.g. '$(GLSCENE)\Source'
  begin
    Relative := False;
  end
  else
    Relative := IsRelativePath(Path);

  if Relative then
    Result := TPath.Combine(ExtractFilePath(IniName), Result);

  Result := ExcludeTrailingPathDelimiter(Result);
end;

procedure Compile(const PackageFileName: string);
var
//  sti: TStartupInfo;
//  pri: TProcessInformation;
  hProc: THandle;
  AppName, CmdLine: string;
  p, c: Integer;
  ExitCode: Cardinal;
  einf: TShellExecuteInfo;
begin
  SetCurrentDir(ExtractFilePath(PackageFileName));

  AppName := 'cmd.exe'; // /C "rsvars.bat';
  CmdLine := '/C "rsvars.bat';

  for c := 0 to High(Configs) do
    for p := 0 to High(Platforms) do
      begin
        CmdLine := CmdLine + ' && msbuild ' + ExtractFileName(PackageFileName) + ' /p:Config=' + Configs[c] + ';Platform=' + Platforms[p] {+ ' && ' +
                   'if ERRORLEVEL 1 pause'};
      end;
  CmdLine := CmdLine + '"';

  Writeln('RUN:');
  Writeln(CmdLine);
//  Readln;

//  FillChar(sti, SizeOf(sti), 0);
//  sti.cb := SizeOf(sti);
//  FillChar(pri, SizeOf(pri), 0);
//
//  if not CreateProcessW(@AppName[1], @CmdLine[1], nil, nil, True, 0, nil, '', sti, pri) then
//    RaiseLastOSError();
//
//  hPrcc := pri.hProcess;
//
//  if AppName <> CmdLine then
//  begin
//
//  end;

  FillChar(einf, SizeOf(einf), 0);
  einf.cbSize := SizeOf(einf);
  einf.fMask := SEE_MASK_NOCLOSEPROCESS or SEE_MASK_NO_CONSOLE;
  einf.lpFile := PChar(AppName);
  einf.lpParameters := PChar(CmdLine);
  einf.nShow := SW_SHOWNORMAL;

  ShellExecuteEx(@einf);

  hProc := einf.hProcess;


  repeat
    if not GetExitCodeProcess(hProc, ExitCode) then
      RaiseLastOSError();
    Sleep(100);
  until ExitCode <> STILL_ACTIVE;


end;

procedure AppendPath(const RegKey, ValueName: string; const Path: string);
// Add Path to semicolon-separated list of paths stored in RegKey\ValueName
var
  s: string;
  r: TRegistry;
  a: TArray<string>;
  i: Integer;
begin
  r := TRegistry.Create();
  try
    r.RootKey := HKEY_CURRENT_USER;
    if r.OpenKey(RegKey, False) then
    try
      s := r.ReadString(ValueName);

      // Already in path?
      a := s.Split([';']);
      for i := 0 to High(a) do
        if SameFileName(Path, ExcludeTrailingPathDelimiter(a[i])) then
        begin
          Writeln('Already in path: ' + Path);
          Exit;
        end;

      if (s <> '') and (s[High(s)] <> ';') then
        s := s + ';';
      s := s + Path;

      r.WriteString(ValueName, s);
      Writeln(RegKey + '\' + ValueName + ' += ' + Path);
    finally
      r.CloseKey();
    end;
  finally
    r.Free;
  end;
end;

procedure AddPaths(const DcuPaths, BrowsingPaths: TArray<string>);
var
  i, p: Integer;
begin
  for p := 0 to High(Platforms) do
    for i := 0 to High(DcuPaths) do
      AppendPath('SOFTWARE\Embarcadero\BDS\21.0\Library\' + Platforms[p], 'Search Path', Trim(FullPath(DcuPaths[i])));
  for p := 0 to High(Platforms) do
    for i := 0 to High(BrowsingPaths) do
      AppendPath('SOFTWARE\Embarcadero\BDS\21.0\Library\' + Platforms[p], 'Browsing Path', Trim(FullPath(BrowsingPaths[i])));
end;

// Compile package for all Platforms and Configs
// Add library path for all Platforms

begin
  try
    if ParamCount() = 0 then
    begin
      raise Exception.Create('Specify dpinst, dpr or dproj file name');
    end;

    IniName := ChangeFileExt(ParamStr(1), '.dpinst');
    Ini := TMemIniFile.Create(IniName);

    Packages := Ini.ReadString('Install', 'Package', ChangeFileExt(IniName, '.dproj')).Split([';']);
    Platforms := Ini.ReadString('Install', 'Platforms', 'Win32;Win64').Split([';']);
    Configs := ['Debug', 'Release'];

    var i: Integer;
    for i := 0 to High(Packages) do
      Compile(FullPath(Packages[i]));

    AddPaths(Ini.ReadString('Install', 'DcuPath', '$(Platform)\$(Config)').Split([';']),
             Ini.ReadString('Install', 'BrowsingPath', '.').Split([';']));

    Ini.Free;

    Write('Press Enter...');
    Readln;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      Write('Press Enter...');
      Readln;
    end;
  end;
end.
