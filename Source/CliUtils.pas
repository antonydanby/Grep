unit CliUtils;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

type
  TCliParams = class
  private
    FParams: TDictionary<string, string>;
   public
     constructor Create;
     destructor Destroy; override;
 
     procedure Parse(const ExeName: string);
     function HasParam(const ParamName: string): Boolean;
     function GetString(const ParamName: string; const DefaultValue: string = ''): string;
     function GetInteger(const ParamName: string; const DefaultValue: Integer = 0): Integer;
     function GetInt64(const ParamName: string; const DefaultValue: Int64 = 0): Int64;
   end;

implementation

constructor TCliParams.Create;
begin
  inherited;
  FParams := TDictionary<string, string>.Create;
end;

destructor TCliParams.Destroy;
begin
  FParams.Free;
  inherited;
end;

procedure TCliParams.Parse(const ExeName: string);
var
  I: Integer;
  CurrentParam: string;
  CurrentValue: string;
  StrParam: string;
begin
  FParams.Clear;

  I := 1;
  while I <= ParamCount do
  begin
    StrParam := ParamStr(I);  // Get parameter at index I

    // Check if it's a parameter (starts with -)
    if (Length(StrParam) > 1) and (StrParam[1] = '-') then
    begin
      CurrentParam := LowerCase(Copy(StrParam, 2, Length(StrParam)));

      // Check if next parameter exists and doesn't start with -
      if (I < ParamCount) then
      begin
        StrParam := ParamStr(I + 1);  // Get next parameter
        if (Length(StrParam) > 0) and (StrParam[1] <> '-') then
        begin
          CurrentValue := StrParam;
          FParams.AddOrSetValue(CurrentParam, CurrentValue);
          Inc(I); // Skip the next parameter as we've consumed it
        end
        else
        begin
          // Parameter with no value (flag)
          FParams.AddOrSetValue(CurrentParam, '1');
        end;
      end
      else
      begin
        // Last parameter with no value (flag)
        FParams.AddOrSetValue(CurrentParam, '1');
      end;
    end;

    Inc(I);
  end;
end;

function TCliParams.HasParam(const ParamName: string): Boolean;
begin
  Result := FParams.ContainsKey(LowerCase(ParamName));
end;

function TCliParams.GetString(const ParamName: string; const DefaultValue: string = ''): string;
var
  Key: string;
begin
  Key := LowerCase(ParamName);
  if FParams.ContainsKey(Key) then
    Result := FParams[Key]
  else
    Result := DefaultValue;
end;

function TCliParams.GetInteger(const ParamName: string; const DefaultValue: Integer = 0): Integer;
var
  StrValue: string;
begin
  StrValue := GetString(ParamName);
  if StrValue <> '' then
  begin
    try
      Result := StrToInt(StrValue);
    except
      Result := DefaultValue;
    end;
  end
  else
    Result := DefaultValue;
end;

function TCliParams.GetInt64(const ParamName: string; const DefaultValue: Int64 = 0): Int64;
var
  StrValue: string;
begin
  StrValue := GetString(ParamName);
  if StrValue <> '' then
  begin
    try
      Result := StrToInt64(StrValue);
    except
      Result := DefaultValue;
    end;
  end
  else
    Result := DefaultValue;
end;

end.
