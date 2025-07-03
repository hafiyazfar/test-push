import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/payment_service.dart';
import '../../../../core/services/logger_service.dart';
import '../../../auth/providers/auth_providers.dart';

final paymentServiceProvider = Provider((ref) => PaymentService());

final donationStatisticsProvider = FutureProvider<DonationStatistics>((ref) async {
  final service = ref.read(paymentServiceProvider);
  return service.getDonationStatistics();
});

final userDonationsProvider = StreamProvider.family<List<DonationRecord>, String>((ref, userId) {
  final service = ref.read(paymentServiceProvider);
  return service.getUserDonations(userId);
});

class DonationPage extends ConsumerStatefulWidget {
  const DonationPage({super.key});

  @override
  ConsumerState<DonationPage> createState() => _DonationPageState();
}

class _DonationPageState extends ConsumerState<DonationPage> {
  final _amountController = TextEditingController();
  final _nameController = TextEditingController();
  final _messageController = TextEditingController();
  
  double? _selectedAmount;
  bool _isAnonymous = false;
  bool _isProcessing = false;
  
  final List<double> _presetAmounts = [10, 25, 50, 100, 250, 500];

  @override
  void initState() {
    super.initState();
    _initializePayment();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _initializePayment() async {
    try {
      final paymentService = ref.read(paymentServiceProvider);
      await paymentService.initializeStripe();
    } catch (e) {
      LoggerService.error('Failed to initialize payment', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;
    final statisticsAsync = ref.watch(donationStatisticsProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Support Our Mission'),
        elevation: 0,
        backgroundColor: AppTheme.primaryColor,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero Section
            _buildHeroSection(),
            
            // Statistics Section
            statisticsAsync.when(
              data: (stats) => _buildStatisticsSection(stats),
              loading: () => const SizedBox(height: 100),
              error: (_, __) => const SizedBox(),
            ),
            
            // Donation Form
            _buildDonationForm(),
            
            // Recent Donations
            if (currentUser != null)
              _buildRecentDonations(currentUser.id),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: FadeInDown(
        duration: const Duration(milliseconds: 600),
        child: Column(
          children: [
            const Icon(
              Icons.favorite,
              size: 64,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            Text(
              'Support Digital Certificate Repository',
              style: AppTheme.headlineMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your donation helps us maintain and improve our secure certificate platform for UPM',
              style: AppTheme.bodyLarge.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsSection(DonationStatistics stats) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          FadeInUp(
            duration: const Duration(milliseconds: 600),
            delay: const Duration(milliseconds: 200),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Total Raised',
                    value: 'RM ${stats.totalAmount.toStringAsFixed(2)}',
                    icon: Icons.account_balance_wallet,
                    color: AppTheme.successColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    title: 'Donors',
                    value: stats.totalCount.toString(),
                    icon: Icons.people,
                    color: AppTheme.infoColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (stats.donationsByMonth.isNotEmpty)
            FadeInUp(
              duration: const Duration(milliseconds: 600),
              delay: const Duration(milliseconds: 400),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monthly Donations',
                        style: AppTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: _buildDonationChart(stats.donationsByMonth),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTheme.headlineSmall.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonationChart(Map<String, double> donationsByMonth) {
    final sortedEntries = donationsByMonth.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    final spots = <FlSpot>[];
    for (int i = 0; i < sortedEntries.length; i++) {
      spots.add(FlSpot(i.toDouble(), sortedEntries[i].value));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < sortedEntries.length) {
                  final month = sortedEntries[index].key.split('-')[1];
                  return Text(
                    DateFormat('MMM').format(DateTime(2024, int.parse(month))),
                    style: AppTheme.bodySmall,
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryColor.withValues(alpha: 0.5),
              ],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.3),
                  AppTheme.primaryColor.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationForm() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: FadeInUp(
        duration: const Duration(milliseconds: 600),
        delay: const Duration(milliseconds: 600),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Make a Donation',
                  style: AppTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                
                // Preset amounts
                Text(
                  'Select Amount (RM)',
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _presetAmounts.map((amount) {
                    final isSelected = _selectedAmount == amount;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedAmount = amount;
                          _amountController.text = amount.toStringAsFixed(0);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryColor : Colors.white,
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Text(
                          'RM $amount',
                          style: AppTheme.bodyMedium.copyWith(
                            color: isSelected ? Colors.white : AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                
                // Custom amount
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Custom Amount (RM)',
                    prefixIcon: const Icon(Icons.attach_money),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _selectedAmount = double.tryParse(value);
                    });
                  },
                ),
                const SizedBox(height: 24),
                
                // Anonymous donation
                CheckboxListTile(
                  value: _isAnonymous,
                  onChanged: (value) {
                    setState(() {
                      _isAnonymous = value ?? false;
                    });
                  },
                  title: const Text('Make donation anonymous'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                
                if (!_isAnonymous) ...[
                  // Donor name
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Your Name (Optional)',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Message
                TextField(
                  controller: _messageController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Message (Optional)',
                    prefixIcon: const Icon(Icons.message),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Donate button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _processDonation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isProcessing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.favorite, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Donate ${_selectedAmount != null ? 'RM ${_selectedAmount!.toStringAsFixed(2)}' : ''}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Security note
                Row(
                  children: [
                    Icon(
                      Icons.lock,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your donation is processed securely through Stripe',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentDonations(String userId) {
    final donationsAsync = ref.watch(userDonationsProvider(userId));
    
    return donationsAsync.when(
      data: (donations) {
        if (donations.isEmpty) return const SizedBox();
        
        return Padding(
          padding: const EdgeInsets.all(16),
          child: FadeInUp(
            duration: const Duration(milliseconds: 600),
            delay: const Duration(milliseconds: 800),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Donation History',
                      style: AppTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    ...donations.take(5).map((donation) => _buildDonationItem(donation)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _buildDonationItem(DonationRecord donation) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.successColor.withValues(alpha: 0.1),
            child: Icon(
              Icons.favorite,
              color: AppTheme.successColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RM ${donation.amount.toStringAsFixed(2)}',
                  style: AppTheme.titleMedium,
                ),
                Text(
                  DateFormat('MMM d, y').format(donation.createdAt),
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              donation.status.toUpperCase(),
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.successColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processDonation() async {
    final amount = _selectedAmount;
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or enter a valid amount'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final paymentService = ref.read(paymentServiceProvider);
      await paymentService.processDonation(
        amount: amount,
        currency: 'MYR',
        donorName: _isAnonymous ? null : _nameController.text,
        message: _messageController.text,
      );

      if (mounted) {
        // Show success
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.successColor),
                const SizedBox(width: 8),
                const Text('Thank You!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your donation of RM ${amount.toStringAsFixed(2)} has been processed successfully.',
                  style: AppTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Thank you for supporting the Digital Certificate Repository!',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );

        // Clear form
        _amountController.clear();
        _nameController.clear();
        _messageController.clear();
        setState(() {
          _selectedAmount = null;
          _isAnonymous = false;
        });
      }
    } catch (e) {
      LoggerService.error('Donation failed', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Donation failed: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
} 