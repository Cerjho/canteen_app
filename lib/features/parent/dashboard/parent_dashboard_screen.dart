import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/models/user_role.dart';
import '../student_link/student_link_screen.dart';
import '../menu/parent_menu_screen.dart';
import '../wallet/wallet_screen.dart';
import '../orders/orders_screen.dart';
import '../student_link/edit_student_screen.dart';
import '../../../shared/utils/date_refresh_controller.dart';

/// Parent Dashboard Screen
/// 
/// This is the main screen for parent users after login.
/// Shows quick summary of:
/// - Linked students overview
/// - Current week's orders and totals
/// - Wallet balance
/// - Notifications for low balance or missing orders
/// - Quick actions: Order Now, Top Up, View Menu
class ParentDashboardScreen extends ConsumerStatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  ConsumerState<ParentDashboardScreen> createState() =>
      _ParentDashboardScreenState();
}

class _ParentDashboardScreenState
    extends ConsumerState<ParentDashboardScreen> {

  late final DateRefreshController _dateController;
  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications coming soon')),
              );
            },
            tooltip: 'Notifications',
          ),
        ],
      ),
      body: currentUserAsync.when(
        data: (user) {
          if (user == null) {
            // If we're authenticated but the profile hasn't streamed in yet,
            // show a short "finishing setup" state with timeout & retry.
            final signedIn = ref.watch(authStateProvider).value != null;
            if (signedIn) {
              return FutureBuilder<void>(
                future: Future.delayed(const Duration(seconds: 10)),
                builder: (_, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Setup taking longer than usual'),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => ref.refresh(currentUserProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    );
                  }
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Finishing account setup...'),
                        ],
                      ),
                    ),
                  );
                },
              );
            }
            return _buildErrorState(context, 'User not found. Please sign in again.');
          }
          
          // Use Builder to ensure ScreenUtil context is available
          return Builder(
            builder: (context) {
              return ResponsiveBuilder(
                builder: (context, sizingInformation) {
                  final isMobile = sizingInformation.deviceScreenType ==
                      DeviceScreenType.mobile;

                  if (isMobile) {
                    return _buildMobileLayout(context, user, ref);
                  }
                  return _buildTabletDesktopLayout(context, user, ref);
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(context, error.toString()),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _dateController = DateRefreshController(onDayChanged: () {
      if (mounted) setState(() {});
    });
    _dateController.start();
    // Also listen to the global dateRefreshProvider so Riverpod-driven changes
    // (used elsewhere) will also trigger a rebuild of this screen.
    // This complements the local controller and ensures consistent behavior.
    ref.listenManual<DateTime>(dateRefreshProvider, (_, __) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _dateController.stop();
    super.dispose();
  }

  // Date changes handled by _dateController callback which calls setState

  /// Build mobile layout (single column)
  Widget _buildMobileLayout(
    BuildContext context,
    AppUser user,
    WidgetRef ref,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        // TODO: Implement refresh logic
        await Future.delayed(const Duration(seconds: 1));
      },
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(context, user),
            SizedBox(height: 16.h),
            _buildQuickActions(context),
            SizedBox(height: 16.h),
            _buildWalletSummary(context),
            SizedBox(height: 16.h),
            _buildLinkedStudents(context),
            SizedBox(height: 16.h),
            _buildWeekOrdersSummary(context),
            SizedBox(height: 16.h),
            _buildRecentActivity(context),
          ],
        ),
      ),
    );
  }

  /// Build tablet/desktop layout (grid)
  Widget _buildTabletDesktopLayout(
    BuildContext context,
    AppUser user,
    WidgetRef ref,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        // TODO: Implement refresh logic
        await Future.delayed(const Duration(seconds: 1));
      },
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(context, user),
            SizedBox(height: 24.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildQuickActions(context),
                      SizedBox(height: 16.h),
                      _buildWalletSummary(context),
                      SizedBox(height: 16.h),
                      _buildWeekOrdersSummary(context),
                    ],
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    children: [
                      _buildLinkedStudents(context),
                      SizedBox(height: 16.h),
                      _buildRecentActivity(context),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build welcome card
  Widget _buildWelcomeCard(BuildContext context, AppUser user) {
  final now = ref.watch(dateRefreshProvider);
  final greeting = now.hour < 12
    ? 'Good Morning'
    : now.hour < 18
      ? 'Good Afternoon'
      : 'Good Evening';

    return Card(
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.secondaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting,',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    user.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    DateFormat('EEEE, MMMM d, y').format(now),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.waving_hand,
              size: 48.sp,
              color: Colors.amber,
            ),
          ],
        ),
      ),
    );
  }

  /// Build quick actions
  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                context,
                icon: Icons.restaurant_menu,
                label: 'Order Now',
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ParentMenuScreen(),
                    ),
                  );
                },
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildActionCard(
                context,
                icon: Icons.account_balance_wallet,
                label: 'Top Up',
                color: Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WalletScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                context,
                icon: Icons.person_add,
                label: 'Link Student',
                color: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StudentLinkScreen(),
                    ),
                  );
                },
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildActionCard(
                context,
                icon: Icons.receipt_long,
                label: 'View Orders',
                color: Colors.orange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OrdersScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            children: [
              CircleAvatar(
                radius: 24.r,
                backgroundColor: color.withAlpha((0.2 * 255).round()),
                child: Icon(icon, color: color, size: 24.sp),
              ),
              SizedBox(height: 8.h),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build wallet summary
  Widget _buildWalletSummary(BuildContext context) {
    // Watch parent profile for real balance
    final parentAsync = ref.watch(currentParentProvider);

    return parentAsync.when(
      data: (parent) {
        final balance = parent?.balance ?? 0.0;
        const lowBalanceThreshold = 500.0;
        final isLowBalance = balance < lowBalanceThreshold;

        return Card(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Wallet Balance',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (isLowBalance)
                      Chip(
                        label: const Text('Low Balance'),
                        avatar: const Icon(Icons.warning_amber, size: 16),
                        backgroundColor: Colors.orange.shade100,
                        labelStyle: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 11.sp,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 16.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          FormatUtils.currency(balance),
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WalletScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Top Up'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Card(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Wallet Balance',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              SizedBox(height: 16.h),
              const Center(
                child: CircularProgressIndicator(),
              ),
            ],
          ),
        ),
      ),
      error: (error, stack) => Card(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Wallet Balance',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 20.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Unable to load balance',
                      style: TextStyle(color: Colors.red, fontSize: 12.sp),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build linked students
  Widget _buildLinkedStudents(BuildContext context) {
    final linkedStudentsAsync = ref.watch(parentStudentsProvider);

    return linkedStudentsAsync.when(
      data: (students) {
        // Show message if no students linked
        if (students.isEmpty) {
          return Card(
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                children: [
                  Icon(
                    Icons.person_add_outlined,
                    size: 48.sp,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'No Linked Students',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Link your first student to get started',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // Show linked students list
        return Card(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Linked Students',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const StudentLinkScreen(),
                          ),
                        );
                      },
                      tooltip: 'Link Student',
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                ...students.map((student) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundImage: student.photoUrl != null
                          ? NetworkImage(student.photoUrl!)
                          : null,
                      child: student.photoUrl == null
                          ? Text(student.fullName[0])
                          : null,
                    ),
                    title: Text(student.fullName),
                    subtitle: Text(student.grade),
                        trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Indicate billing model: parents are billed (student balances are admin-only)
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,                       
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          iconSize: 20.sp,
                          tooltip: 'Edit Details',
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditStudentScreen(
                                  student: student,
                                ),
                              ),
                            );
                            // Refresh if changes were made
                            if (result == true) {
                              ref.invalidate(parentStudentsProvider);
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
      loading: () => Card(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (error, stack) => Card(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            children: [
              Icon(
                Icons.error_outline,
                size: 48.sp,
                color: Colors.red,
              ),
              SizedBox(height: 12.h),
              Text(
                'Error loading students',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.red,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build week orders summary
  Widget _buildWeekOrdersSummary(BuildContext context) {
    // TODO: Get actual orders from provider
    const weekOrders = 12;
    const weekSpending = 1250.0;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This Week',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 32.sp,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        '$weekOrders',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'Orders',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 60.h,
                  color: Theme.of(context).dividerColor,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Icon(
                        Icons.payments_outlined,
                        size: 32.sp,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        FormatUtils.currency(weekSpending),
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'Spent',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build recent activity
  Widget _buildRecentActivity(BuildContext context) {
    // TODO: Get actual recent activity from provider
    final mockActivity = [
      {
        'type': 'order',
        'title': 'Order Confirmed',
        'subtitle': 'Order #12345 for Juan',
        'time': '2 hours ago',
        'icon': Icons.check_circle,
        'color': Colors.green,
      },
      {
        'type': 'topup',
        'title': 'Wallet Top-up',
        'subtitle': '+${FormatUtils.currency(1000)}',
        'time': '1 day ago',
        'icon': Icons.account_balance_wallet,
        'color': Colors.blue,
      },
      {
        'type': 'order',
        'title': 'Order Delivered',
        'subtitle': 'Order #12344 for Maria',
        'time': '2 days ago',
        'icon': Icons.delivery_dining,
        'color': Colors.purple,
      },
    ];

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Activity',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OrdersScreen(),
                      ),
                    );
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            ...mockActivity.map((activity) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: (activity['color'] as Color).withAlpha((0.2 * 255).round()),
                  child: Icon(
                    activity['icon'] as IconData,
                    color: activity['color'] as Color,
                  ),
                ),
                title: Text(activity['title'].toString()),
                subtitle: Text(activity['subtitle'].toString()),
                trailing: Text(
                  activity['time'].toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Build error state
  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64.sp,
              color: Colors.red,
            ),
            SizedBox(height: 16.h),
            Text(
              'Error Loading Dashboard',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8.h),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

