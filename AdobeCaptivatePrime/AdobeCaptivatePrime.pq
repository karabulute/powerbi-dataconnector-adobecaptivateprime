[Version = "1.0.0"] // Requirement for certification

section AdobeCaptivatePrime;
[DataSource.Kind="AdobeCaptivatePrime", Publish="AdobeCaptivatePrime.Publish"]

shared AdobeCaptivatePrime.Navigator = Value.ReplaceType(AdobeCaptivatePrimeImpl, AdobeCaptivatePrimeType);

    AdobeCaptivatePrimeType =  type function (
        server_instance as (type text meta [
            Documentation.FieldCaption = Extension.LoadString("TablesDocsFieldCaption"),
            Documentation.FieldDescription = Extension.LoadString("TablesDocsFieldDesc"),
            Documentation.SampleValues = Table.ToList(Table.FromValue(Extension.LoadString("TablesDocsSampleValues"))),
            Formatting.IsMultiLine = false,
            Formatting.IsCode = false
            ])) as table meta [
                Documentation.Name = Extension.LoadString("TablesDocsName"),
                Documentation.LongDescription = Extension.LoadString("TablesDocsLongDesc"),
                Documentation.Examples = {[
                    Description = Extension.LoadString("TablesDocsExamplesDesc"),
                    Code = Extension.LoadString("TablesDocsExamplesCode"),
                    Result = Extension.LoadString("TablesDocsExamplesResult") 
                ]}
            ];

    AdobeCaptivatePrimeImpl = (server_instance as text) =>
        let
            objects = #table(
                {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},{
                {"Badges", "badges", AdobeCaptivatePrime.Tables(server_instance, "badges"), "Table", "Table", true},
                {"Users", "users", AdobeCaptivatePrime.Tables(server_instance, "users"), "Table", "Table", true},
                {"UserGroups", "userGroups", AdobeCaptivatePrime.Tables(server_instance, "userGroups"), "Table", "Table", true},
                {"Catalogs", "catalogs", AdobeCaptivatePrime.Tables(server_instance, "catalogs"), "Table", "Table", true},
                {"Skills", "skills", AdobeCaptivatePrime.Tables(server_instance, "skills"), "Table", "Table", true},
                {"LearningObjects", "learningObjects", AdobeCaptivatePrime.Tables(server_instance, "learningObjects"), "Table", "Table", true},
                {"getUserBadges", "getuserbadges", AdobeCaptivatePrime.getUserBadges, "Function", "Function", true},
                {"getUserEnrollments", "getUserEnrollments", AdobeCaptivatePrime.getUserEnrollments, "Function", "Function", true}
                }),
            NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
        in
            NavTable;

shared AdobeCaptivatePrime.Tables = (server_instance as text, endpoint as text) as table => 
    let
        Records = GetAllPagesByNextLink("https://" & server_instance & ".adobe.com/primeapi/v2/" & endpoint),
        Table = ExpandAttributes(Records)
    in
        Table;

shared AdobeCaptivatePrime.getUserBadges = (server_instance as text, userId as text) as table => 
    let
        Records = GetAllPagesByNextLink("https://" & server_instance & ".adobe.com/primeapi/v2/users/" & userId & "/userBadges"),
        Table = ExpandAttributes(Records)
    in
        Table;

shared AdobeCaptivatePrime.getUserEnrollments = (server_instance as text, userId as text) as table => 
    let
        Records = GetAllPagesByNextLink("https://" & server_instance & ".adobe.com/primeapi/v2/users/" & userId & "/enrollments?filter.loTypes=course%2ClearningProgram%2CjobAid%2Ccertification"),
        Table = ExpandAttributes(Records)
    in
        Table;

DefaultRequestHeaders = [
    #"Authorization" = "oauth " & Extension.CurrentCredential()[Key],
    #"Accept" = "application/vnd.api+json"
];      
       
AdobeCaptivatePrime = [
    Authentication = [
        Key = [
            KeyLabel =  Extension.LoadString("AuthenticationKeyKeyLabel"),
            Label =  Extension.LoadString("AuthenticationKeyLabel")
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

AdobeCaptivatePrime.Publish = [
    Beta = true, // Soft requirement for certification
    Category = "Online Services",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://github.com/karabulute/powerbi-dataconnector-adobecaptivateprime",
    SourceImage = AdobeCaptivatePrime.Icons,
    SourceTypeImage = AdobeCaptivatePrime.Icons
];

AdobeCaptivatePrime.Icons = [ // Soft requirement for certification
    Icon16 = { 
        Extension.Contents("AdobeCaptivatePrime16.png"),
        Extension.Contents("AdobeCaptivatePrime20.png"),
        Extension.Contents("AdobeCaptivatePrime24.png"),
        Extension.Contents("AdobeCaptivatePrime32.png")
    },
    Icon32 = {
        Extension.Contents("AdobeCaptivatePrime32.png"),
        Extension.Contents("AdobeCaptivatePrime40.png"),
        Extension.Contents("AdobeCaptivatePrime48.png"),
        Extension.Contents("AdobeCaptivatePrime64.png")
    }
];

GetPage = (url as text) as table =>
    let
        response = Web.Contents(url, [ Headers = DefaultRequestHeaders ]),        
        body = Json.Document(response),
        nextLink = GetNextLink(body),
        data = Table.FromRecords(body[data])
    in
        data meta [NextLink = nextLink];

GetNextLink = (response) as nullable text =>  try response[links][next] otherwise null;

GetAllPagesByNextLink = (url as text) as table =>
    Table.GenerateByPage((previous) => 
        let
            nextLink = if (previous = null) then url else Value.Metadata(previous)[NextLink]?,
            page = if (nextLink <> null) then GetPage(nextLink) else null
        in
            page
    );

ExpandAttributes = (records as table) as table =>
    let
        ExpandedRecords = if Table.HasColumns(records, "attributes")
            then Table.ExpandRecordColumn(records, "attributes", Record.FieldNames(records{0}[attributes]))
            else records
    in
        ExpandedRecords;

Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            Preview.DelayColumn = itemNameColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;

Table.GenerateByPage = (getNextPage as function) as table =>
    let        
        listOfPages = List.Generate(
            () => getNextPage(null),
            (lastPage) => lastPage <> null,
            (lastPage) => getNextPage(lastPage)
        ),
        tableOfPages = Table.FromList(listOfPages, Splitter.SplitByNothing(), {"Column1"}),
        firstRow = tableOfPages{0}?
    in
        if (firstRow = null) then
            Table.FromRows({})
        else        
            Value.ReplaceType(
                Table.ExpandTableColumn(tableOfPages, "Column1", Table.ColumnNames(firstRow[Column1])),
                Value.Type(firstRow[Column1])
            );