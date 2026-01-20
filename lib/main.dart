import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'services.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.purple,
        useMaterial3: true,
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  File? _selectedImage;
  Uint8List? _processedImage;
  bool _isLoading = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 100,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _processedImage = null;
          _tabController.index = 0;
        });
      }
    } catch (e) {
      _showSnackBar("Error: $e", isError: true);
    }
  }

  Future<void> _removeWatermark() async {
    if (_selectedImage == null) {
      _showSnackBar(AppConstants.selectImageError, isError: true);
      return;
    }

    setState(() => _isLoading = true);

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Processing image...'),
            SizedBox(height: 8),
            Text(
              'This may take 30-90 seconds',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );

    try {
      print('🚀 Starting watermark removal...');
      final result = await ApiService.removeWatermark(_selectedImage!);

      // Close progress dialog
      Navigator.of(context).pop();

      if (result != null) {
        setState(() {
          _processedImage = result;
          _isLoading = false;
          _tabController.index = 1;
        });
        _showSnackBar(AppConstants.successMessage, isError: false);
      } else {
        throw Exception('No result returned');
      }
    } catch (e) {
      // Close progress dialog
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      setState(() => _isLoading = false);

      print('💥 Error caught: $e');

      // Show error dialog with retry option
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Error'),
            ],
          ),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _removeWatermark(); // Retry
              },
              child: Text('Retry'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
        ),
      );
    }
  }


  // ═══════════════════════════════════════════════════════════
  // DOWNLOAD TO DEVICE STORAGE
  // ═══════════════════════════════════════════════════════════
  Future<void> _downloadImage() async {
    if (_processedImage == null) return;

    setState(() => _isLoading = true);

    try {
      // Get Downloads directory
      Directory? directory;

      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final fileName = 'watermark_removed_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${directory!.path}/$fileName');

      await file.writeAsBytes(_processedImage!);

      setState(() => _isLoading = false);
      _showSnackBar('✅ Downloaded to: ${directory.path}', isError: false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Download error: $e", isError: true);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // SAVE TO GALLERY
  // ═══════════════════════════════════════════════════════════
  Future<void> _saveToGallery() async {
    if (_processedImage == null) return;

    setState(() => _isLoading = true);

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/watermark_removed_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(_processedImage!);

      await Gal.putImage(file.path);

      setState(() => _isLoading = false);
      _showSnackBar(AppConstants.saveSuccessMessage, isError: false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Save error: $e", isError: true);
    }
  }

  Future<void> _shareImage() async {
    if (_processedImage == null) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/watermark_removed.png');
      await file.writeAsBytes(_processedImage!);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Cleaned with Watermark Remover Pro',
      );
    } catch (e) {
      _showSnackBar("Share error: $e", isError: true);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // CONNECTION ERROR DIALOG
  // ═══════════════════════════════════════════════════════════
  void _showConnectionErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Connection Error'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cannot connect to server. Please check:'),
            SizedBox(height: 12),
            _buildCheckItem('✓ Backend is running on PC'),
            _buildCheckItem('✓ Phone & PC on same WiFi'),
            _buildCheckItem('✓ IP address is correct'),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Server: ${AppConstants.apiUrl}',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
          SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.purple[50]!, Colors.blue[50]!],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _selectedImage == null
                    ? _buildEmptyState()
                    : _buildImageViewer(),
              ),
              _buildBottomActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.purple, Colors.purpleAccent]),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(Icons.auto_fix_high, color: Colors.white, size: 28),
          ),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppConstants.appTitle,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple[900],
                ),
              ),
              Text(
                AppConstants.appSubtitle,
                style: TextStyle(fontSize: 12, color: Colors.purple[700]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(40),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.purple[100]!, Colors.blue[100]!],
              ),
            ),
            child: Icon(Icons.image_outlined, size: 80, color: Colors.purple[300]),
          ),
          SizedBox(height: 24),
          Text(
            'No Image Selected',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.purple[900],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Pick an image to get started',
            style: TextStyle(fontSize: 16, color: Colors.purple[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildImageViewer() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(15),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.purple, Colors.purpleAccent]),
                borderRadius: BorderRadius.circular(15),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[700],
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library, size: 20),
                      SizedBox(width: 8),
                      Text('Original'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_fix_high, size: 20),
                      SizedBox(width: 8),
                      Text('Cleaned'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildImageContainer(
                  child: Image.file(_selectedImage!, fit: BoxFit.contain),
                ),
                _processedImage != null
                    ? _buildImageContainer(
                  child: Image.memory(_processedImage!, fit: BoxFit.contain),
                  showActions: true,
                )
                    : _buildNoProcessedImage(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageContainer({required Widget child, bool showActions = false}) {
    return Container(
      margin: EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: child,
            ),
          ),
          if (showActions) ...[
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.save_alt,
                    label: 'Gallery',
                    onPressed: _saveToGallery,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.download,
                    label: 'Download',
                    onPressed: _downloadImage,
                    color: Colors.teal,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.share,
                    label: 'Share',
                    onPressed: _shareImage,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoProcessedImage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_fix_off, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No processed image yet',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Click "Remove Watermark" below',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildGradientButton(
                  text: 'Gallery',
                  icon: Icons.photo_library,
                  onPressed: () => _pickImage(ImageSource.gallery),
                  colors: [Colors.blue[400]!, Colors.blue[600]!],
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildGradientButton(
                  text: 'Camera',
                  icon: Icons.camera_alt,
                  onPressed: () => _pickImage(ImageSource.camera),
                  colors: [Colors.teal[400]!, Colors.teal[600]!],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildGradientButton(
            text: _isLoading ? 'Processing...' : 'Remove Watermark',
            icon: Icons.auto_fix_high,
            onPressed: _removeWatermark,
            colors: [Colors.purple[400]!, Colors.purple[700]!],
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildGradientButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    required List<Color> colors,
    bool isLoading = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: colors[0].withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                else
                  Icon(icon, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  text,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}