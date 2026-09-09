object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'Grep'
  ClientHeight = 761
  ClientWidth = 884
  Color = clBtnFace
  Constraints.MinHeight = 800
  Constraints.MinWidth = 900
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object HeaderPanel: TPanel
    Left = 0
    Top = 0
    Width = 884
    Height = 60
    Align = alTop
    BevelOuter = bvNone
    ParentBackground = False
    TabOrder = 0
    DesignSize = (
      884
      60)
    object TitleLabel: TLabel
      Left = 24
      Top = 6
      Width = 79
      Height = 25
      Caption = 'Grep VCL'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -19
      Font.Name = 'Segoe UI Semibold'
      Font.Style = []
      ParentFont = False
    end
    object SubtitleLabel: TLabel
      Left = 24
      Top = 36
      Width = 380
      Height = 15
      Caption = 
        'Search with text or regex, preview match context, and optionally' +
        ' replace.'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGrayText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object btnSearch: TButton
      Left = 646
      Top = 17
      Width = 110
      Height = 28
      Anchors = [akTop, akRight]
      Caption = 'Search'
      TabOrder = 0
      OnClick = btnSearchClick
    end
    object btnClear: TButton
      Left = 762
      Top = 17
      Width = 110
      Height = 28
      Anchors = [akTop, akRight]
      Caption = 'Clear'
      TabOrder = 1
      OnClick = btnClearClick
    end
  end
  object BodyPanel: TPanel
    Left = 0
    Top = 60
    Width = 884
    Height = 682
    Align = alClient
    BevelOuter = bvNone
    ParentBackground = False
    TabOrder = 1
    ExplicitTop = 70
    ExplicitHeight = 691
    object FiltersPanel: TPanel
      Left = 0
      Top = 0
      Width = 370
      Height = 682
      Align = alLeft
      BevelOuter = bvNone
      ParentBackground = False
      TabOrder = 0
      ExplicitHeight = 691
      object FiltersScrollBox: TScrollBox
        Left = 16
        Top = 16
        Width = 350
        Height = 653
        VertScrollBar.Tracking = True
        Align = alCustom
        Anchors = [akLeft, akTop, akRight, akBottom]
        BorderStyle = bsNone
        Color = clBtnFace
        ParentColor = False
        TabOrder = 0
        ExplicitHeight = 659
        object SearchCard: TPanel
          Left = 0
          Top = 0
          Width = 350
          Height = 337
          Align = alTop
          BevelOuter = bvNone
          ParentBackground = False
          TabOrder = 0
          ExplicitLeft = 4
          ExplicitTop = -6
          object SearchCardTitle: TLabel
            Left = 14
            Top = 12
            Width = 46
            Height = 20
            Caption = 'Search'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 4737096
            Font.Height = -15
            Font.Name = 'Segoe UI Semibold'
            Font.Style = []
            ParentFont = False
          end
          object SearchCardDivider: TShape
            Left = 14
            Top = 40
            Width = 304
            Height = 1
            Brush.Color = 15263976
            Pen.Color = 15263976
          end
          object lblFolder: TLabel
            Left = 14
            Top = 56
            Width = 33
            Height = 15
            Caption = 'Folder'
          end
          object lblFind: TLabel
            Left = 14
            Top = 105
            Width = 23
            Height = 15
            Caption = 'Find'
          end
          object lblReplace: TLabel
            Left = 14
            Top = 154
            Width = 67
            Height = 15
            Caption = 'Replace with'
          end
          object lblWildcards: TLabel
            Left = 14
            Top = 203
            Width = 101
            Height = 15
            Caption = 'Filename wildcards'
          end
          object lblContextLines: TLabel
            Left = 194
            Top = 203
            Width = 68
            Height = 15
            Caption = 'Context lines'
          end
          object edtFolder: TEdit
            Left = 14
            Top = 74
            Width = 244
            Height = 23
            TabOrder = 0
          end
          object btnBrowse: TButton
            Left = 264
            Top = 73
            Width = 54
            Height = 25
            Caption = '...'
            TabOrder = 1
            OnClick = btnBrowseClick
          end
          object edtSearchText: TEdit
            Left = 14
            Top = 123
            Width = 304
            Height = 23
            TabOrder = 2
          end
          object edtReplaceText: TEdit
            Left = 14
            Top = 172
            Width = 304
            Height = 23
            TabOrder = 3
          end
          object edtWildcards: TEdit
            Left = 14
            Top = 221
            Width = 150
            Height = 23
            TabOrder = 4
            Text = '*.*'
          end
          object spnContextLines: TSpinEdit
            Left = 194
            Top = 221
            Width = 124
            Height = 24
            MaxValue = 20
            MinValue = 0
            TabOrder = 5
            Value = 3
          end
          object swRegex: TCheckBox
            Left = 14
            Top = 259
            Width = 304
            Height = 17
            Caption = 'Use regex'
            TabOrder = 6
            OnClick = ToggleModeChanged
          end
          object swCaseSensitive: TCheckBox
            Left = 14
            Top = 285
            Width = 304
            Height = 17
            Caption = 'Case sensitive'
            TabOrder = 7
            OnClick = ToggleModeChanged
          end
          object swReplaceMode: TCheckBox
            Left = 14
            Top = 311
            Width = 304
            Height = 17
            Caption = 'Replace mode'
            TabOrder = 8
            OnClick = ToggleModeChanged
          end
        end
        object FiltersCard: TPanel
          Left = 0
          Top = 341
          Width = 350
          Height = 312
          Align = alBottom
          BevelOuter = bvNone
          ParentBackground = False
          TabOrder = 1
          ExplicitTop = 347
          object FiltersCardTitle: TLabel
            Left = 14
            Top = 12
            Width = 41
            Height = 20
            Caption = 'Filters'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 4737096
            Font.Height = -15
            Font.Name = 'Segoe UI Semibold'
            Font.Style = []
            ParentFont = False
          end
          object FiltersCardDivider: TShape
            Left = 14
            Top = 40
            Width = 304
            Height = 1
            Brush.Color = 15263976
            Pen.Color = 15263976
          end
          object lblMinSize: TLabel
            Left = 14
            Top = 256
            Width = 101
            Height = 15
            Caption = 'Min file size (bytes)'
          end
          object lblMaxSize: TLabel
            Left = 174
            Top = 256
            Width = 102
            Height = 15
            Caption = 'Max file size (bytes)'
          end
          object swIncludeSubfolders: TCheckBox
            Left = 14
            Top = 56
            Width = 304
            Height = 17
            Caption = 'Include subfolders'
            Checked = True
            State = cbChecked
            TabOrder = 0
          end
          object swIncludeHidden: TCheckBox
            Left = 14
            Top = 82
            Width = 304
            Height = 17
            Caption = 'Include hidden files'
            TabOrder = 1
          end
          object swIncludeBinary: TCheckBox
            Left = 14
            Top = 108
            Width = 304
            Height = 17
            Caption = 'Include binary files'
            TabOrder = 2
          end
          object swUseDateFrom: TCheckBox
            Left = 14
            Top = 138
            Width = 304
            Height = 17
            Caption = 'Use modified from date'
            TabOrder = 3
            OnClick = ToggleModeChanged
          end
          object dtpDateFrom: TDateTimePicker
            Left = 14
            Top = 164
            Width = 304
            Height = 23
            Date = 46255.000000000000000000
            Time = 46255.000000000000000000
            TabOrder = 4
          end
          object swUseDateTo: TCheckBox
            Left = 14
            Top = 195
            Width = 304
            Height = 17
            Caption = 'Use modified to date'
            TabOrder = 5
            OnClick = ToggleModeChanged
          end
          object dtpDateTo: TDateTimePicker
            Left = 14
            Top = 221
            Width = 304
            Height = 23
            Date = 46255.000000000000000000
            Time = 46255.000000000000000000
            TabOrder = 6
          end
          object edtMinSize: TEdit
            Left = 14
            Top = 274
            Width = 144
            Height = 23
            TabOrder = 7
          end
          object edtMaxSize: TEdit
            Left = 174
            Top = 274
            Width = 144
            Height = 23
            TabOrder = 8
          end
        end
        object Panel1: TPanel
          Left = 0
          Top = 337
          Width = 350
          Height = 4
          Align = alClient
          BevelOuter = bvNone
          Constraints.MinHeight = 4
          ParentBackground = False
          TabOrder = 2
          ExplicitHeight = 10
        end
      end
    end
    object ResultsPanel: TPanel
      Left = 370
      Top = 0
      Width = 514
      Height = 682
      Align = alClient
      BevelOuter = bvNone
      ParentBackground = False
      TabOrder = 1
      ExplicitHeight = 691
      object MatchesPanel: TPanel
        Left = 0
        Top = 0
        Width = 514
        Height = 682
        Align = alClient
        BevelOuter = bvNone
        BorderWidth = 12
        ParentBackground = False
        TabOrder = 0
        ExplicitLeft = 6
        ExplicitTop = 16
        ExplicitWidth = 490
        ExplicitHeight = 657
        object TogglePanel: TPanel
          Left = 12
          Top = 670
          Width = 490
          Height = 0
          Align = alBottom
          BevelOuter = bvNone
          Color = clWhite
          ParentBackground = False
          TabOrder = 0
          Visible = False
          OnClick = TogglePanelClick
          ExplicitLeft = 4
          ExplicitTop = 653
          ExplicitWidth = 482
        end
        object MatchesListView: TListView
          Left = 12
          Top = 68
          Width = 490
          Height = 602
          Align = alClient
          Columns = <
            item
              Caption = 'File'
              Width = 350
            end
            item
              Caption = 'Line'
              Width = 70
            end
            item
              Caption = 'Match'
              Width = 300
            end>
          ColumnClick = False
          ReadOnly = True
          RowSelect = True
          TabOrder = 1
          ViewStyle = vsReport
          OnSelectItem = MatchesListViewSelectItem
          ExplicitLeft = 4
          ExplicitTop = 60
          ExplicitWidth = 482
          ExplicitHeight = 593
        end
        object ResultsHeaderPanel: TPanel
          Left = 12
          Top = 12
          Width = 490
          Height = 56
          Align = alTop
          BevelOuter = bvNone
          ParentBackground = False
          TabOrder = 2
          ExplicitLeft = 4
          ExplicitTop = 4
          ExplicitWidth = 482
          object ResultsTitleLabel: TLabel
            Left = 0
            Top = 8
            Width = 69
            Height = 20
            Caption = 'Results (0)'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 4737096
            Font.Height = -15
            Font.Name = 'Segoe UI Semibold'
            Font.Style = []
            ParentFont = False
          end
          object ResultsStatusLabel: TLabel
            Left = 0
            Top = 28
            Width = 32
            Height = 15
            Caption = 'Ready'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clGrayText
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
          end
        end
      end
    end
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 742
    Width = 884
    Height = 19
    Panels = <>
    ExplicitLeft = 384
    ExplicitTop = 680
    ExplicitWidth = 0
  end
end
