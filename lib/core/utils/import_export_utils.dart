import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

/// Utility class for common import/export operations
/// 
/// This class provides reusable methods for:
/// - CSV parsing and generation
/// - Excel parsing and generation
/// - File validation
/// - Data transformation
/// 
/// Usage:
/// ```dart
/// // Parse CSV
/// final data = ImportExportUtils.parseCsv(csvString);
/// 
/// // Generate CSV
/// final csv = ImportExportUtils.generateCsv(data, headers);
/// 
/// // Parse Excel
/// final data = ImportExportUtils.parseExcel(excelBytes);
/// ```
class ImportExportUtils {
  ImportExportUtils._(); // Private constructor to prevent instantiation

  // ============================================================================
  // CSV Operations
  // ============================================================================

  /// Parse CSV string into list of maps
  /// 
  /// Parameters:
  /// - [csvString]: CSV content as string
  /// - [hasHeaders]: Whether first row contains headers (default: true)
  /// 
  /// Returns: List of maps where keys are column headers
  /// 
  /// Example:
  /// ```dart
  /// final csv = 'name,age\nJohn,30\nJane,25';
  /// final data = ImportExportUtils.parseCsv(csv);
  /// // Result: [{'name': 'John', 'age': '30'}, {'name': 'Jane', 'age': '25'}]
  /// ```
  static List<Map<String, String>> parseCsv(
    String csvString, {
    bool hasHeaders = true,
  }) {
    final List<List<dynamic>> csvTable = const CsvToListConverter().convert(
      csvString,
      eol: '\n',
      fieldDelimiter: ',',
    );

    if (csvTable.isEmpty) {
      return [];
    }

    if (!hasHeaders) {
      // Generate headers like Column1, Column2, etc.
      final columnCount = csvTable[0].length;
      final headers = List.generate(columnCount, (i) => 'Column${i + 1}');
      return _convertToMapList(headers, csvTable);
    }

    final headers = csvTable[0].map((e) => e.toString()).toList();
    final dataRows = csvTable.skip(1).toList();

    return _convertToMapList(headers, dataRows);
  }

  /// Generate CSV string from list of maps
  /// 
  /// Parameters:
  /// - [data]: List of maps to convert to CSV
  /// - [headers]: List of column headers (keys to extract from maps)
  /// - [includeHeaders]: Whether to include header row (default: true)
  /// 
  /// Returns: CSV formatted string
  /// 
  /// Example:
  /// ```dart
  /// final data = [{'name': 'John', 'age': '30'}];
  /// final csv = ImportExportUtils.generateCsv(data, ['name', 'age']);
  /// // Result: "name,age\nJohn,30"
  /// ```
  static String generateCsv(
    List<Map<String, dynamic>> data,
    List<String> headers, {
    bool includeHeaders = true,
  }) {
    final List<List<dynamic>> csvData = [];

    if (includeHeaders) {
      csvData.add(headers);
    }

    for (final row in data) {
      final rowData = headers.map((header) {
        final value = row[header];
        return value?.toString() ?? '';
      }).toList();
      csvData.add(rowData);
    }

    return const ListToCsvConverter().convert(csvData);
  }

  // ============================================================================
  // Excel Operations
  // ============================================================================

  /// Parse Excel bytes into list of maps
  /// 
  /// Parameters:
  /// - [bytes]: Excel file as Uint8List
  /// - [sheetName]: Name of sheet to parse (default: first sheet)
  /// - [hasHeaders]: Whether first row contains headers (default: true)
  /// 
  /// Returns: List of maps where keys are column headers
  /// 
  /// Throws: Exception if file cannot be parsed or sheet not found
  static List<Map<String, String>> parseExcel(
    Uint8List bytes, {
    String? sheetName,
    bool hasHeaders = true,
  }) {
    final excel = Excel.decodeBytes(bytes);

    // Get the sheet to parse
    String targetSheet;
    if (sheetName != null) {
      if (!excel.tables.containsKey(sheetName)) {
        throw Exception('Sheet "$sheetName" not found in Excel file');
      }
      targetSheet = sheetName;
    } else {
      // Use first sheet
      if (excel.tables.isEmpty) {
        throw Exception('No sheets found in Excel file');
      }
      targetSheet = excel.tables.keys.first;
    }

    final sheet = excel.tables[targetSheet];
    if (sheet == null || sheet.rows.isEmpty) {
      return [];
    }

    final rows = sheet.rows;

    if (!hasHeaders) {
      // Generate headers
      final columnCount = rows[0].length;
      final headers = List.generate(columnCount, (i) => 'Column${i + 1}');
      return _convertExcelToMapList(headers, rows);
    }

    // Extract headers from first row
    final headers = rows[0].map((cell) => cell?.value?.toString() ?? '').toList();
    final dataRows = rows.skip(1).toList();

    return _convertExcelToMapList(headers, dataRows);
  }

  /// Generate Excel bytes from list of maps
  /// 
  /// Parameters:
  /// - [data]: List of maps to convert to Excel
  /// - [headers]: List of column headers
  /// - [sheetName]: Name for the sheet (default: 'Sheet1')
  /// - [includeHeaders]: Whether to include header row (default: true)
  /// 
  /// Returns: Excel file as Uint8List
  static Uint8List generateExcel(
    List<Map<String, dynamic>> data,
    List<String> headers, {
    String sheetName = 'Sheet1',
    bool includeHeaders = true,
  }) {
    final excel = Excel.createExcel();
    final sheet = excel[sheetName];

    int rowIndex = 0;

    // Add headers
    if (includeHeaders) {
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex))
            .value = TextCellValue(headers[i]);
      }
      rowIndex++;
    }

    // Add data rows
    for (final row in data) {
      for (int i = 0; i < headers.length; i++) {
        final value = row[headers[i]];
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex))
            .value = TextCellValue(value?.toString() ?? '');
      }
      rowIndex++;
    }

    return Uint8List.fromList(excel.encode()!);
  }

  // ============================================================================
  // File Validation
  // ============================================================================

  /// Validate file extension
  /// 
  /// Parameters:
  /// - [fileName]: Name of the file
  /// - [allowedExtensions]: List of allowed extensions (e.g., ['.csv', '.xlsx'])
  /// 
  /// Returns: true if valid, false otherwise
  static bool validateFileExtension(
    String fileName,
    List<String> allowedExtensions,
  ) {
    final lowerFileName = fileName.toLowerCase();
    return allowedExtensions.any((ext) => lowerFileName.endsWith(ext.toLowerCase()));
  }

  /// Detect file type from file name
  /// 
  /// Returns: 'csv', 'xlsx', 'xls', or 'unknown'
  static String detectFileType(String fileName) {
    final lowerFileName = fileName.toLowerCase();
    if (lowerFileName.endsWith('.csv')) return 'csv';
    if (lowerFileName.endsWith('.xlsx')) return 'xlsx';
    if (lowerFileName.endsWith('.xls')) return 'xls';
    return 'unknown';
  }

  /// Validate CSV structure
  /// 
  /// Parameters:
  /// - [csvString]: CSV content
  /// - [requiredHeaders]: List of required column headers
  /// - [minRows]: Minimum number of data rows required (default: 1)
  /// 
  /// Returns: Map with validation result
  /// ```dart
  /// {
  ///   'isValid': true/false,
  ///   'error': 'error message' or null,
  ///   'missingHeaders': [...] or null,
  ///   'rowCount': number of data rows
  /// }
  /// ```
  static Map<String, dynamic> validateCsvStructure(
    String csvString,
    List<String> requiredHeaders, {
    int minRows = 1,
  }) {
    try {
      final data = parseCsv(csvString);

      if (data.isEmpty) {
        return {
          'isValid': false,
          'error': 'CSV file is empty',
          'missingHeaders': null,
          'rowCount': 0,
        };
      }

      // Check for required headers
      final actualHeaders = data[0].keys.toList();
      final missingHeaders = requiredHeaders
          .where((header) => !actualHeaders.contains(header))
          .toList();

      if (missingHeaders.isNotEmpty) {
        return {
          'isValid': false,
          'error': 'Missing required columns: ${missingHeaders.join(", ")}',
          'missingHeaders': missingHeaders,
          'rowCount': data.length,
        };
      }

      // Check minimum rows
      if (data.length < minRows) {
        return {
          'isValid': false,
          'error': 'File must contain at least $minRows data row(s)',
          'missingHeaders': null,
          'rowCount': data.length,
        };
      }

      return {
        'isValid': true,
        'error': null,
        'missingHeaders': null,
        'rowCount': data.length,
      };
    } catch (e) {
      return {
        'isValid': false,
        'error': 'Failed to parse CSV: ${e.toString()}',
        'missingHeaders': null,
        'rowCount': 0,
      };
    }
  }

  // ============================================================================
  // Data Transformation Helpers
  // ============================================================================

  /// Clean and trim all string values in a map
  static Map<String, String> cleanMapData(Map<String, String> data) {
    return data.map((key, value) => MapEntry(key, value.trim()));
  }

  /// Remove empty rows from parsed data
  static List<Map<String, String>> removeEmptyRows(
    List<Map<String, String>> data,
  ) {
    return data.where((row) {
      return row.values.any((value) => value.isNotEmpty);
    }).toList();
  }

  /// Convert column values to lowercase for case-insensitive matching
  static List<Map<String, String>> normalizeHeaders(
    List<Map<String, String>> data,
  ) {
    return data.map((row) {
      return row.map((key, value) => MapEntry(key.toLowerCase(), value));
    }).toList();
  }

  // ============================================================================
  // Private Helper Methods
  // ============================================================================

  static List<Map<String, String>> _convertToMapList(
    List<String> headers,
    List<List<dynamic>> rows,
  ) {
    final result = <Map<String, String>>[];

    for (final row in rows) {
      final Map<String, String> rowMap = {};
      for (int i = 0; i < headers.length; i++) {
        final value = i < row.length ? row[i]?.toString() ?? '' : '';
        rowMap[headers[i]] = value;
      }
      result.add(rowMap);
    }

    return result;
  }

  static List<Map<String, String>> _convertExcelToMapList(
    List<String> headers,
    List<List<Data?>> rows,
  ) {
    final result = <Map<String, String>>[];

    for (final row in rows) {
      final Map<String, String> rowMap = {};
      for (int i = 0; i < headers.length; i++) {
        final value = i < row.length ? row[i]?.value?.toString() ?? '' : '';
        rowMap[headers[i]] = value;
      }
      result.add(rowMap);
    }

    return result;
  }
}
