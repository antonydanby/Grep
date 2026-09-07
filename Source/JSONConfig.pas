unit JSONConfig;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes,
  System.IOUtils, System.DateUtils,
  System.JSON, System.Generics.Collections;

type
  TJSONConfig = class
  private
    //fValue: string;
    fJSONObject: TJSONObject;
    fConfigFilePath: string;

    function GetJsonValue(const aKey: string): TJsonValue;
    function GetValue: string;
    procedure SetValue(const aValue: string);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;

    // --- File Operations ---
    function LoadFromFile(const aFilePath: string; aCreateIfNotExists: Boolean = False): Boolean;
    function SaveToFile(const aFilePath: string): Boolean;

    // --- Key Management ---
    function HasKey(const aKey: string): Boolean;
    procedure DeleteKey(const aKey: string);

    // --- Setter Methods (to store values) ---
    procedure SetString(const aKey, aValue: string);
    procedure SetInteger(const aKey: string; aValue: Integer);
    procedure SetFloat(const aKey: string; aValue: Double);
    procedure SetBoolean(const aKey: string; aValue: Boolean);
    procedure SetDateTime(const aKey: string; aValue: TDateTime);
    procedure SetTime(const aKey: string; aValue: TTime);
    procedure SetJSONArray(const aKey: string; aValue: TJSONArray);

    // --- Getter Methods (to retrieve values) ---
    function GetString(const aKey: string; const aDefault: string = ''): string;
    function GetInteger(const aKey: string; const aDefault: Integer = 0): Integer;
    function GetFloat(const aKey: string; const aDefault: Double = 0.0): Double;
    function GetBoolean(const aKey: string; const aDefault: Boolean = False): Boolean;
    function GetDateTime(const aKey: string; const aDefault: TDateTime = 0): TDateTime;
    function GetTime(const aKey: string; const aDefault: TTime = 0): TTime;
    function GetJSONArray(const aKey: string): TJSONArray;

    property ConfigFilePath: string read fConfigFilePath write fConfigFilePath;
    property Value: string read GetValue write SetValue;
  end;

implementation

{ TJSONConfig }

constructor TJSONConfig.Create;
begin
  inherited;
  fJSONObject := TJSONObject.Create;
  fConfigFilePath := '';
end;

destructor TJSONConfig.Destroy;
begin
  fJSONObject.Free;
  inherited;
end;

procedure TJSONConfig.Clear;
begin
  fJSONObject.Free;
  fJSONObject := TJSONObject.Create;
end;

function TJSONConfig.GetJsonValue(const aKey: string): TJsonValue;
begin
  Result := fJSONObject.GetValue(aKey);
end;

function TJSONConfig.LoadFromFile(const aFilePath: string; aCreateIfNotExists: Boolean = False): Boolean;
var
  jsonString: string;
  jsonValue: TJsonValue;
begin
  Result := False;
  fConfigFilePath := aFilePath;

  if not TFile.Exists(aFilePath) then
  begin
    if aCreateIfNotExists then
    begin
      // Create empty config and save it
      Clear;
      Result := SaveToFile(aFilePath);
    end
    else
      raise Exception.CreateFmt('TJSONConfig.LoadFromFile: Configuration file not found: %s',[aFilePath]);
    Exit;
  end;

  try
    jsonString := TFile.ReadAllText(aFilePath);
    jsonValue := TJSONObject.ParseJsonValue(jsonString);
    try
      if Assigned(jsonValue) and (jsonValue is TJSONObject) then
      begin
        fJSONObject.Free; // Free existing object
        fJSONObject := jsonValue as TJSONObject; // Assign new object
        Result := True;
      end
      else
      begin
        jsonValue.Free; // Free the non-object JSON value
        raise Exception.CreateFmt('TJSONConfig.LoadFromFile: Invalid JSON structure in file: %s',[aFilePath]);
      end;
    except
      on E: Exception do
      begin
        // Ensure jsonValue is freed if an error occurs during parsing or type checking
        if Assigned(jsonValue) then jsonValue.Free;
        raise Exception.CreateFmt('TJSONConfig.LoadFromFile: Error parsing JSON from file: %s',[aFilePath]);
      end;
    end;
  except
    on E: Exception do
    begin
      raise Exception.CreateFmt('TJSONConfig.LoadFromFile: Error reading config file: %s',[aFilePath]);
    end;
  end;
end;

function TJSONConfig.SaveToFile(const aFilePath: string): Boolean;
begin
  Result := False;
  fConfigFilePath := aFilePath;

  try
    TFile.WriteAllText(aFilePath, fJSONObject.ToJSON);
    Result := True;
  except
    on E: Exception do
    begin
      raise Exception.CreateFmt('TJSONConfig.SaveToFile: Error saving config file to: %s',[aFilePath]);
    end;
  end;
end;

function TJSONConfig.HasKey(const aKey: string): Boolean;
begin
  Result := GetJsonValue(aKey) <> nil;
end;

procedure TJSONConfig.DeleteKey(const aKey: string);
var
  value: TJsonValue;
begin
  value := GetJsonValue(aKey);
  if Assigned(value) then fJSONObject.RemovePair(aKey);
end;

procedure TJSONConfig.SetString(const aKey, aValue: string);
begin
  fJSONObject.AddPair(aKey, aValue);
end;

procedure TJSONConfig.SetInteger(const aKey: string; aValue: Integer);
begin
  fJSONObject.AddPair(aKey, TJSONNumber.Create(aValue));
end;

procedure TJSONConfig.SetFloat(const aKey: string; aValue: Double);
begin
  fJSONObject.AddPair(aKey, TJSONNumber.Create(aValue));
end;

procedure TJSONConfig.SetBoolean(const aKey: string; aValue: Boolean);
begin
  fJSONObject.AddPair(aKey, TJSONBool.Create(aValue));
end;

procedure TJSONConfig.SetDateTime(const aKey: string; aValue: TDateTime);
begin
  // Store TDateTime as an ISO 8601 string for unambiguous representation
  // Example: '2023-10-27T10:30:00.000Z'
  fJSONObject.AddPair(aKey, DateToISO8601(aValue));
end;

procedure TJSONConfig.SetTime(const aKey: string; aValue: TTime);
begin
  fJSONObject.AddPair(aKey, FormatDateTime('hh:nn', aValue));
end;

procedure TJSONConfig.SetJSONArray(const aKey: string; aValue: TJSONArray);
begin
  // Add a clone of the array. AddPair will take ownership of the clone,
  // leaving the original object's ownership with the caller.
  fJSONObject.AddPair(aKey, TJSONArray(aValue.Clone));
end;

function TJSONConfig.GetString(const aKey: string; const aDefault: string): string;
var
  jsonValue: TJsonValue;
begin
  jsonValue := GetJsonValue(aKey);
  if Assigned(jsonValue) and (jsonValue is TJSONString) then
    Result := TJSONString(jsonValue).Value
  else
    Result := aDefault;
end;

function TJSONConfig.GetInteger(const aKey: string; const aDefault: Integer): Integer;
var
  jsonValue: TJsonValue;
begin
  Result := aDefault;
  jsonValue := GetJsonValue(aKey);
  if Assigned(jsonValue) then
  begin
    if (jsonValue is TJSONNumber) then
    begin
      try
        Result := TJSONNumber(jsonValue).AsInt;
      except
        on E: Exception do
        begin
          raise Exception.CreateFmt('TJSONConfig.GetInteger: Error converting JSON number to Integer for Key: %s', [aKey]);
        end;
      end;
    end
    else
    begin
      raise Exception.CreateFmt('TJSONConfig.GetInteger: Value for Key "%s" is not a JSON Number.', [aKey]);
    end;
  end;
end;

function TJSONConfig.GetFloat(const aKey: string; const aDefault: Double): Double;
var
  jsonValue: TJsonValue;
begin
  Result := aDefault;
  jsonValue := GetJsonValue(aKey);
  if Assigned(jsonValue) then
  begin
    if (jsonValue is TJSONNumber) then
    begin
      try
        Result := TJSONNumber(jsonValue).AsDouble;
      except
        on E: Exception do
        begin
          raise Exception.CreateFmt('TJSONConfig.GetFloat: Error converting JSON number to Float for Key: %s', [aKey]);
        end;
      end;
    end
    else
    begin
      raise Exception.CreateFmt('TJSONConfig.GetFloat: Value for Key "%s" is not a JSON Number.', [aKey]);
    end;
  end;
end;

function TJSONConfig.GetBoolean(const aKey: string; const aDefault: Boolean): Boolean;
var
  jsonValue: TJsonValue;
begin
  jsonValue := GetJsonValue(aKey);
  if Assigned(jsonValue) and (jsonValue is TJSONBool) then
    Result := TJSONBool(jsonValue).AsBoolean
  else
    Result := aDefault;
end;

function TJSONConfig.GetDateTime(const aKey: string; const aDefault: TDateTime): TDateTime;
var
  jsonValue: TJsonValue;
  datetimeStr: string;
begin
  Result := aDefault;
  jsonValue := GetJsonValue(aKey);
  if Assigned(jsonValue) then
  begin
    if (jsonValue is TJSONString) then
    begin
      datetimeStr := TJSONString(jsonValue).Value;
      try
        // Amendment: Use ISO8601ToDateTime to parse full date and time
        Result := ISO8601ToDate(datetimeStr);
      except
        on E: Exception do
        begin
          raise Exception.CreateFmt('TJSONConfig.GetDateTime: Error parsing DateTime string for key %s', [aKey]);
        end;
      end;
    end
    else
    begin
      raise Exception.CreateFmt('TJSONConfig.GetDateTime: Value for Key "%s" is not a JSON String.', [aKey]);
    end;
  end;
end;

function TJSONConfig.GetTime(const aKey: string; const aDefault: TTime): TTime;
var
  jsonValue: TJsonValue;
  timeStr: string;
begin
  Result := aDefault;
  jsonValue := GetJsonValue(aKey);
  if Assigned(jsonValue) then
  begin
    if (jsonValue is TJSONString) then
    begin
      timeStr := TJSONString(jsonValue).Value;
      try
        Result := StrToTime(timeStr);
      except
        on E: Exception do
        begin
          raise Exception.CreateFmt('TJSONConfig.GetTime: Error parsing Time string for key %s', [aKey]);
        end;
      end;
    end
    else
    begin
      raise Exception.CreateFmt('TJSONConfig.GetTime: Value for Key "%s" is not a JSON String.', [aKey]);
    end;
  end;
end;

function TJSONConfig.GetJSONArray(const aKey: string): TJSONArray;
var
  jsonValue: TJsonValue;
begin
  Result := nil;
  jsonValue := GetJsonValue(aKey);
  if Assigned(jsonValue) and (jsonValue is TJSONArray) then
    // Return a clone. The caller is responsible for freeing this new object.
    Result := TJSONArray(jsonValue.Clone)
  // If key doesn't exist or is not an array, Result remains nil.
end;

function TJSONConfig.GetValue: string;
begin
  Result := fJSONObject.ToJSON;
end;

procedure TJSONConfig.SetValue(const aValue: string);
var
  newJSONObject: TJSONObject;
  jsonValue: TJsonValue;
begin
  jsonValue := nil; // Initialize to nil
  try
    jsonValue := TJSONObject.ParseJsonValue(aValue); // Parse the input string
    if Assigned(jsonValue) and (jsonValue is TJSONObject) then
    begin
      newJSONObject := jsonValue as TJSONObject; // Cast to TJSONObject
      fJSONObject.Free; // Free the old object to prevent memory leaks
      fJSONObject := newJSONObject; // Assign the new object
    end
    else
    begin
      // If parsing fails or the root is not a JSON object, raise an exception
      raise Exception.Create('TJSONConfig.SetValue: Invalid JSON format or not a JSON Object.');
    end;
  finally
    // Ensure JSONValue is freed only if it's not the one assigned to fJSONObject
    if Assigned(jsonValue) and (jsonValue <> fJSONObject) then jsonValue.Free;
  end;
end;

end.
