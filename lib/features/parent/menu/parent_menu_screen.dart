import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../shared/utils/date_refresh_controller.dart';
import '../../../core/providers/date_refresh_provider.dart';
import '../../../core/models/menu_item.dart';
import '../../../core/models/weekly_menu.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/selected_student_provider.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/providers/day_of_order_provider.dart';
import '../../../core/providers/weekly_cart_provider.dart';
import '../../../shared/components/loading_indicator.dart';
import '../cart/cart_screen.dart';
import '../cart/weekly_cart_screen.dart';
import 'widgets/food_card.dart';
import 'widgets/menu_detail_panel.dart';

/// Parent Menu Screen - Enhanced responsive layout for weekly menu browsing and ordering
/// 
/// Layouts:
/// - Mobile (<600px): Single-pane vertical ListView
/// - Tablet (600-1200px): 2-column GridView
/// - Web (>1200px): 4-column GridView with NavigationRail for categories and detail pane
/// 
/// Features:
/// - Weekly menu calendar browsing
/// - Advance vs day-of ordering modes
/// - Filter by category and search
/// - View item details
/// - Add items to cart or day-of order
/// - Admin approval workflow for day-of orders
/// - Real-time notifications
/// - Responsive scaling using flutter_screenutil (base: 360x690px)
/// 
/// Note: Bottom navigation is handled by parent_app.dart at the app level
class ParentMenuScreen extends ConsumerStatefulWidget {
  const ParentMenuScreen({super.key});

  @override
  ConsumerState<ParentMenuScreen> createState() => _ParentMenuScreenState();
}

class _ParentMenuScreenState extends ConsumerState<ParentMenuScreen> {

  late final DateRefreshController _dateController;
  String _selectedCategory = 'All';
  MenuItem? _selectedItem; // For master-detail view on larger screens
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  
  // Cart mode: 'daily' or 'weekly' (only for advance orders)
  String _cartMode = 'weekly';
  
  // Calendar state
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  // DateRefreshMixin provides currentDate and lifecycle handling
  
  // Computed order mode based on selected date
  String get _orderMode {
    final now = ref.watch(dateRefreshProvider);
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    
    return selected == today ? 'dayOf' : 'advance';
  }
  
  // Search query
  String _searchQuery = '';
  
  // Categories for filtering
  final List<String> _categories = ['All', 'Snack', 'Lunch', 'Drinks'];

  @override
  void initState() {
    super.initState();
    // Initialize calendar selection from centralized date provider so the
    // widget doesn't capture a stale DateTime at declaration time.
    final now = ref.read(dateRefreshProvider);
  final today = DateTime(now.year, now.month, now.day);
  _focusedDay = today;
    _selectedDay = DateTime(now.year, now.month, now.day);
    _dateController = DateRefreshController(onDayChanged: () {
      if (mounted) onDayChanged();
    });
    _dateController.start();
    // Ensure Riverpod-driven date changes also rebuild this screen.
    ref.listenManual<DateTime?>(dateRefreshProvider, (_, __) {
      if (mounted) onDayChanged();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isReminderTime()) {
        final nextMonday = _getNextMonday();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '📅 Plan next week’s meals! Order by Sunday 8 PM for ${DateFormat('MMM d').format(nextMonday)}.',
            ),
            backgroundColor: Colors.orange[700],
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Plan Now',
              textColor: Colors.white,
              onPressed: () {
                setState(() {
                  _selectedDay = nextMonday;
                  _focusedDay = nextMonday;
                  _cartMode = 'weekly';
                });
              },
            ),
          ),
        );
      }
    });
  }

  void onDayChanged() {
    // If the selected day is before the new today, move selection to today.
    final now = ref.read(dateRefreshProvider);
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    setState(() {
      if (selected.isBefore(today)) {
        _selectedDay = today;
        _focusedDay = today;
      } else {
        // Clamp focusedDay to today or later
        _focusedDay = selected.isBefore(today) ? today : selected;
      }
    });
  }

  @override
  void dispose() {
    _dateController.stop();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // (dispose handled above where lifecycle observer and timers are cleaned up)

  // Helper: Is it time to show the weekend reminder?
  bool _isReminderTime() {
    final now = ref.read(dateRefreshProvider);
    final isFridayEvening = now.weekday == DateTime.friday && now.hour >= 18;
    final isSaturday = now.weekday == DateTime.saturday;
    final isSundayMorning = now.weekday == DateTime.sunday && now.hour < 12;
    return isFridayEvening || isSaturday || isSundayMorning;
  }

  // Helper: Get the next Monday from today
  DateTime _getNextMonday() {
  final now = ref.read(dateRefreshProvider);
  final daysUntilMonday = (DateTime.monday - now.weekday + 7) % 7;
  return daysUntilMonday == 0
    ? now.add(const Duration(days: 7))
    : now.add(Duration(days: daysUntilMonday));
  }

  // Get items scheduled for selected day from weekly menu
  List<MenuItem> _getScheduledItems(List<MenuItem> allMenuItems, WeeklyMenu? weeklyMenu) {
    // If no menu published, return empty list
    if (weeklyMenu == null || !weeklyMenu.isPublished) {
      return [];
    }
    
    // Get day name (e.g., "Monday")
    final dayName = DateFormat('EEEE').format(_selectedDay);
    
    // Get menu for this day
    final dayMenu = weeklyMenu.menuByDay[dayName];
    if (dayMenu == null) {
      return [];
    }
    
    // Collect all item IDs scheduled for this day based on category filter
    final scheduledIds = <String>[];
    
    if (_selectedCategory == 'All') {
      // Show all meal types
      scheduledIds.addAll(dayMenu[MealType.snack] ?? []);
      scheduledIds.addAll(dayMenu[MealType.lunch] ?? []);
      scheduledIds.addAll(dayMenu[MealType.drinks] ?? []);
    } else if (_selectedCategory == 'Snack') {
      scheduledIds.addAll(dayMenu[MealType.snack] ?? []);
    } else if (_selectedCategory == 'Lunch') {
      scheduledIds.addAll(dayMenu[MealType.lunch] ?? []);
    } else if (_selectedCategory == 'Drinks') {
      scheduledIds.addAll(dayMenu[MealType.drinks] ?? []);
    }
    
    // Filter menu items to only scheduled ones
    var filteredItems = allMenuItems
        .where((item) => scheduledIds.contains(item.id))
        .toList();
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filteredItems = filteredItems
          .where((item) =>
              item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              item.description.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    
    return filteredItems;
  }

  // Validate if selected date is valid for current order mode
  // Auto-switch mode based on selected date
  void _handleDateSelection(DateTime selectedDay) {
  final now = ref.read(dateRefreshProvider);
  final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    
    // Prevent selecting past dates
    if (selected.isBefore(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You can only select today or future dates for ordering.'),
          backgroundColor: Colors.grey,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _selectedDay = today;
        _focusedDay = today;
      });
      return;
    }
    setState(() {
      _selectedDay = selectedDay;
      // Clamp focusedDay to today or later
      _focusedDay = selectedDay.isBefore(today) ? today : selectedDay;
    });
    // Show helpful tip when selecting today (day-of order) in daily mode only
    if (selected == today && _cartMode == 'daily') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('📢 Same-day order requires admin approval (subject to availability)'),
          backgroundColor: Colors.orange[700],
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Initialize ScreenUtil for responsive scaling
    ScreenUtil.init(
      context,
      designSize: const Size(360, 690), // Base design size
      minTextAdapt: true,
    );

    // Student chip selector UI
    final parentStudentsAsync = ref.watch(parentStudentsProvider);
    final selectedStudent = ref.watch(selectedStudentProvider);
    Widget studentChipSelector = parentStudentsAsync.when(
      data: (students) {
        if (students.isEmpty) {
          return Padding(
            padding: EdgeInsets.all(12.0),
            child: Text('No linked students', style: TextStyle(color: Colors.grey)),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text('Select Student:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: students.map((student) {
                  final isSelected = selectedStudent?.id == student.id;
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: ChoiceChip(
                      label: Row(
                        children: [
                          if (student.photoUrl != null && student.photoUrl!.isNotEmpty)
                            CircleAvatar(
                              radius: 12,
                              backgroundImage: NetworkImage(student.photoUrl!),
                            )
                          else
                            Icon(Icons.face, size: 20),
                          SizedBox(width: 6),
                          Text(student.firstName),
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          ref.read(selectedStudentProvider.notifier).state = student;
                        }
                      },
                      selectedColor: Theme.of(context).colorScheme.primary,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
      loading: () => Padding(
        padding: EdgeInsets.all(12.0),
        child: CircularProgressIndicator(),
      ),
      error: (err, stack) => Padding(
        padding: EdgeInsets.all(12.0),
        child: Text('Error loading students', style: TextStyle(color: Colors.red)),
      ),
    );

    return ResponsiveBuilder(
      builder: (context, sizingInformation) {
        // Determine device type
        final deviceType = sizingInformation.deviceScreenType;
        final screenWidth = sizingInformation.screenSize.width;
        final isMobile = deviceType == DeviceScreenType.mobile;
        final isTablet = deviceType == DeviceScreenType.tablet;
        final isDesktop = deviceType == DeviceScreenType.desktop;

        return Scaffold(
          appBar: _buildAppBar(isMobile),
          body: SafeArea(
            child: Column(
              children: [
                studentChipSelector,
                Expanded(
                  child: OrientationBuilder(
                    builder: (context, orientation) {
                      if (isDesktop || (isTablet && orientation == Orientation.landscape)) {
                        // Master-detail layout for desktop/tablet landscape
                        return _buildMasterDetailLayout(screenWidth, orientation);
                      } else {
                        // Single pane layout for mobile/tablet portrait
                        return _buildSinglePaneLayout(isMobile, isTablet, screenWidth, orientation);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          // Bottom navigation is handled by parent_app.dart at the app level
          floatingActionButton: _orderMode == 'dayOf' ? _buildSubmitButton() : null,
        );
      },
    );
  }

  // AppBar with responsive design
  PreferredSizeWidget _buildAppBar(bool isMobile) {
    // Watch cart item count for badge (for advance orders)
    final cartItemCount = ref.watch(cartItemCountProvider);
    // Watch day-of order count for badge
    final dayOfOrderCount = ref.watch(dayOfOrderItemCountProvider);
    // Watch weekly cart item count
    final weeklyCartItemCount = ref.watch(weeklyCartItemCountProvider);
    
    final badgeCount = _orderMode == 'advance' 
        ? (_cartMode == 'daily' ? cartItemCount : weeklyCartItemCount)
        : dayOfOrderCount;

    return AppBar(
      title: Text(
        'Canteen Menu',
        style: TextStyle(
          fontSize: isMobile ? 18.sp : 20.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        // Cart mode toggle (always visible)
        PopupMenuButton<String>(
          icon: Icon(
            _cartMode == 'daily' ? Icons.today : Icons.view_week,
            size: isMobile ? 22.sp : 24.sp,
          ),
          tooltip: 'Cart Mode',
            onSelected: (mode) {
              setState(() {
                _cartMode = mode;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'daily',
                child: Row(
                  children: [
                    Icon(
                      Icons.today,
                      size: 20.sp,
                      color: _cartMode == 'daily' 
                          ? Theme.of(context).colorScheme.primary 
                          : null,
                    ),
                    SizedBox(width: 12.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Cart',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: _cartMode == 'daily' 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                          ),
                        ),
                        Text(
                          'Order day by day',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    if (_cartMode == 'daily') ...[
                      const Spacer(),
                      Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                        size: 18.sp,
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'weekly',
                child: Row(
                  children: [
                    Icon(
                      Icons.view_week,
                      size: 20.sp,
                      color: _cartMode == 'weekly' 
                          ? Theme.of(context).colorScheme.primary 
                          : null,
                    ),
                    SizedBox(width: 12.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weekly Bundle',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: _cartMode == 'weekly' 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                          ),
                        ),
                        Text(
                          'Plan Mon-Fri at once',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    if (_cartMode == 'weekly') ...[
                      const Spacer(),
                      Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                        size: 18.sp,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        
        SizedBox(width: 8.w),
        
        // Cart/Order icon with badge
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(
                _orderMode == 'advance'
                    ? Icons.shopping_cart
                    : Icons.pending_actions,
                size: isMobile ? 22.sp : 24.sp,
              ),
              onPressed: () {
                if (_orderMode == 'advance') {
                  // Navigate to appropriate cart screen
                  if (_cartMode == 'daily') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CartScreen()),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WeeklyCartScreen(
                          weekStartDate: _selectedDay,
                        ),
                      ),
                    );
                  }
                } else {
                  // Show day-of orders
                  _showDayOfOrdersDialog();
                }
              },
              tooltip: _orderMode == 'advance' 
                  ? (_cartMode == 'daily' ? 'Daily Cart' : 'Weekly Cart')
                  : 'Day-of Orders',
            ),
            // Badge for item count
            if (badgeCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: EdgeInsets.all(2.w),
                  decoration: BoxDecoration(
                    color: _orderMode == 'advance' ? Colors.red : Colors.orange,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  constraints: BoxConstraints(
                    minWidth: 16.w,
                    minHeight: 16.h,
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(width: 8.w),
      ],
    );
  }

  // Submit button for day-of orders
  Widget? _buildSubmitButton() {
    final dayOfOrderCount = ref.watch(dayOfOrderItemCountProvider);
    
    if (dayOfOrderCount == 0) return null;

    return FloatingActionButton.extended(
      onPressed: _submitDayOfOrders,
      backgroundColor: Colors.purple[700],
      icon: const Icon(Icons.send),
      label: Text('Submit for Approval ($dayOfOrderCount)'),
    );
  }

  // Master-detail layout for desktop and tablet landscape
  Widget _buildMasterDetailLayout(double screenWidth, Orientation orientation) {
    return Row(
      children: [
        // NavigationRail for category selection
        _buildNavigationRail(),
        
        // Vertical divider
        const VerticalDivider(thickness: 1, width: 1),
        
        // Main content area
        Expanded(
          flex: _selectedItem == null ? 3 : 2,
          child: Column(
            children: [
              // Calendar (only in weekly mode)
              if (_cartMode == 'weekly')
                _buildCalendar(false),
              
              // Search bar
              _buildSearchBar(false),
              
              // Date mode warning (if date invalid for selected order mode)
              _buildDateModeWarning(),
              
              // Menu items grid (master)
              Expanded(
                child: _buildMenuGrid(screenWidth, orientation),
              ),
            ],
          ),
        ),
        
        // Detail pane (if item selected)
        if (_selectedItem != null) ...[
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            flex: 1,
            child: MenuDetailPanel(
              item: _selectedItem!,
              onClose: () {
                setState(() {
                  _selectedItem = null;
                });
              },
              onAddToCart: () => _addToOrder(_selectedItem!),
            ),
          ),
        ],
      ],
    );
  }

  // NavigationRail for desktop/tablet landscape
  Widget _buildNavigationRail() {
    return NavigationRail(
      selectedIndex: _categories.indexOf(_selectedCategory),
      onDestinationSelected: (index) {
        setState(() {
          _selectedCategory = _categories[index];
          _selectedItem = null; // Clear selection when changing category
        });
      },
      labelType: NavigationRailLabelType.all,
      destinations: _categories.map((category) {
        IconData icon;
        switch (category) {
          case 'All':
            icon = Icons.restaurant_menu;
            break;
          case 'Snack':
            icon = Icons.cookie;
            break;
          case 'Lunch':
            icon = Icons.lunch_dining;
            break;
          case 'Drinks':
            icon = Icons.local_drink;
            break;
          default:
            icon = Icons.category;
        }
        return NavigationRailDestination(
          icon: Icon(icon),
          selectedIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
          label: Text(category),
        );
      }).toList(),
    );
  }

  // Single pane layout for mobile and tablet portrait
  Widget _buildSinglePaneLayout(
    bool isMobile,
    bool isTablet,
    double screenWidth,
    Orientation orientation,
  ) {
    return Column(
      children: [
        // Compact calendar for week browsing (only in weekly mode)
        if (_cartMode == 'weekly')
          _buildCalendar(isMobile),
        
        // Search bar
        _buildSearchBar(isMobile),
        
        // Date mode warning (if date invalid for selected order mode)
        _buildDateModeWarning(),
        
        // Category chips for filtering
        _buildCategoryChips(isMobile),
        
        // Menu items grid
        Expanded(
          child: _buildMenuGrid(screenWidth, orientation),
        ),
      ],
    );
  }

  // Compact weekly calendar
  Widget _buildCalendar(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Builder(builder: (context) {
        // Snapshot the global today value so all derived dates are consistent
        final today = ref.read(dateRefreshProvider);
        final firstDay = DateTime(today.year, today.month, today.day);
        final lastDay = today.add(const Duration(days: 30));

        // Clamp focused day into visible range
        DateTime focusedDayForCalendar = _focusedDay;
        if (focusedDayForCalendar.isBefore(firstDay)) focusedDayForCalendar = firstDay;
        if (focusedDayForCalendar.isAfter(lastDay)) focusedDayForCalendar = lastDay;

        return TableCalendar(
          firstDay: firstDay,
          lastDay: lastDay,
          focusedDay: focusedDayForCalendar,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          enabledDayPredicate: (day) {
            final todayLocal = ref.read(dateRefreshProvider);
            final d = DateTime(day.year, day.month, day.day);
            return !d.isBefore(DateTime(todayLocal.year, todayLocal.month, todayLocal.day));
          },
          calendarFormat: CalendarFormat.week,
          startingDayOfWeek: StartingDayOfWeek.monday,
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, focusedDay) {
              final todayLocal = ref.read(dateRefreshProvider);
              final d = DateTime(day.year, day.month, day.day);
              final isPast = d.isBefore(DateTime(todayLocal.year, todayLocal.month, todayLocal.day));
              return _buildCalendarDay(day, isSchoolDay: _isSchoolDay(day), isMobile: isMobile, isPast: isPast);
            },
            todayBuilder: (context, day, focusedDay) {
              final todayLocal = ref.read(dateRefreshProvider);
              final d = DateTime(day.year, day.month, day.day);
              final isPast = d.isBefore(DateTime(todayLocal.year, todayLocal.month, todayLocal.day));
              return _buildCalendarDay(day, isToday: true, isSchoolDay: _isSchoolDay(day), isMobile: isMobile, isPast: isPast);
            },
            outsideBuilder: (context, day, focusedDay) {
              final todayLocal = ref.read(dateRefreshProvider);
              final d = DateTime(day.year, day.month, day.day);
              final isPast = d.isBefore(DateTime(todayLocal.year, todayLocal.month, todayLocal.day));
              return _buildCalendarDay(day, isOutside: true, isSchoolDay: _isSchoolDay(day), isMobile: isMobile, isPast: isPast);
            },
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(
              fontSize: isMobile ? 13.sp : 14.sp,
              fontWeight: FontWeight.w600,
            ),
            leftChevronIcon: Icon(Icons.chevron_left, size: isMobile ? 18.sp : 20.sp),
            rightChevronIcon: Icon(Icons.chevron_right, size: isMobile ? 18.sp : 20.sp),
            headerPadding: EdgeInsets.symmetric(vertical: 4.h),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: TextStyle(fontSize: isMobile ? 9.sp : 10.sp),
            weekendStyle: TextStyle(fontSize: isMobile ? 9.sp : 10.sp, color: Colors.red[300]),
          ),
          daysOfWeekHeight: 20.h,
          calendarStyle: CalendarStyle(
            cellMargin: EdgeInsets.all(2.w),
            todayDecoration: BoxDecoration(
              color: Colors.purple[100],
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Colors.purple[700],
              shape: BoxShape.circle,
            ),
            todayTextStyle: TextStyle(
              color: Colors.purple[900],
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 11.sp : 12.sp,
            ),
            selectedTextStyle: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 11.sp : 12.sp,
            ),
            defaultTextStyle: TextStyle(fontSize: isMobile ? 11.sp : 12.sp),
            weekendTextStyle: TextStyle(fontSize: isMobile ? 11.sp : 12.sp, color: Colors.red[300]),
          ),
          onDaySelected: (selectedDay, focusedDay) {
            _handleDateSelection(selectedDay);
          },
          onPageChanged: (focusedDay) {
            setState(() {
              // Clamp focusedDay to today or later
              final now = ref.read(dateRefreshProvider);
              final today = DateTime(now.year, now.month, now.day);
              _focusedDay = focusedDay.isBefore(today) ? today : focusedDay;
            });
          },
        );
      }),
    );
  }

  // Check if a day is a school day (Mon-Fri, not a holiday)
  bool _isSchoolDay(DateTime day) {
    // Weekends are not school days
    if (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
      return false;
    }
    
    // TODO: Add holiday checking logic here
    // For now, all Mon-Fri are school days
    return true;
  }

  // Build custom calendar day with school day highlighting
  Widget _buildCalendarDay(
    DateTime day, {
    bool isToday = false,
    bool isOutside = false,
    bool isSchoolDay = true,
    required bool isMobile,
    bool isPast = false,
  }) {
    final isSelected = isSameDay(day, _selectedDay);
    final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
  final now = ref.read(dateRefreshProvider);
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(day.year, day.month, day.day);
  final isPast = d.isBefore(today);

    Color? backgroundColor;
    Color? textColor;
    Color? borderColor;

    if (isPast) {
      backgroundColor = Colors.grey[200];
      textColor = Colors.grey[400];
    } else if (isSelected) {
      backgroundColor = Colors.purple[700];
      textColor = Colors.white;
    } else if (isToday) {
      backgroundColor = Colors.purple[100];
      textColor = Colors.purple[900];
      borderColor = Colors.purple[700];
    } else if (!isSchoolDay) {
      backgroundColor = Colors.grey[200];
      textColor = Colors.grey[500];
    } else if (isSchoolDay && !isWeekend) {
      backgroundColor = Colors.green[50];
      textColor = Colors.green[900];
    } else {
      textColor = isWeekend ? Colors.red[300] : Colors.black87;
    }

    return IgnorePointer(
      ignoring: isPast,
      child: Container(
        margin: EdgeInsets.all(2.w),
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: borderColor != null ? Border.all(color: borderColor, width: 1.5) : null,
        ),
        child: Center(
          child: Text(
            '${day.day}',
            style: TextStyle(
              fontSize: isMobile ? 11.sp : 12.sp,
              fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  // Search bar
  Widget _buildSearchBar(bool isMobile) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search menu items...',
          hintStyle: TextStyle(fontSize: isMobile ? 14.sp : 16.sp),
          prefixIcon: Icon(Icons.search, size: isMobile ? 20.sp : 24.sp),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, size: isMobile ? 20.sp : 24.sp),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.r),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        ),
        style: TextStyle(fontSize: isMobile ? 14.sp : 16.sp),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  // Order mode toggle (Advance vs Day-of)
  // Category filter chips
  Widget _buildCategoryChips(bool isMobile) {
    return Container(
      height: isMobile ? 36.h : 40.h,
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (context, index) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;
          
          return Semantics(
            label: '$category category',
            button: true,
            selected: isSelected,
            child: ChoiceChip(
              label: Text(
                category,
                style: TextStyle(
                  fontSize: isMobile ? 12.sp : 13.sp,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              selectedColor: Colors.purple[100],
              labelStyle: TextStyle(
                color: isSelected ? Colors.purple[900] : Colors.grey[700],
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedCategory = category;
                    _selectedItem = null;
                  });
                }
              },
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              visualDensity: VisualDensity.compact,
            ),
          );
        },
      ),
    );
  }

  // Add item to cart or day-of order based on mode
  void _addToOrder(MenuItem item, {int quantity = 1}) {
    final selectedStudent = ref.read(selectedStudentProvider);
    if (selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a student before adding items.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_orderMode == 'advance') {
      if (_cartMode == 'daily') {
        // Add to regular daily cart with quantity, tagging student
        for (int i = 0; i < quantity; i++) {
          ref.read(cartProvider.notifier).addItem(
            item,
            studentId: selectedStudent.id,
            studentName: selectedStudent.fullName,
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(quantity > 1 
                ? 'Added $quantity x ${item.name} for ${selectedStudent.firstName}' 
                : '${item.name} added for ${selectedStudent.firstName}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'View Cart',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CartScreen()),
                );
              },
            ),
          ),
        );
      } else {
        // Add to weekly cart for selected date, tagging student
        ref.read(weeklyCartProvider.notifier).addItemForDate(
          item,
          _selectedDay,
          quantity: quantity,
          studentId: selectedStudent.id,
          studentName: selectedStudent.fullName,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(quantity > 1 
                ? 'Added $quantity x ${item.name} for ${selectedStudent.firstName} to ${_formatDate(_selectedDay)}' 
                : '${item.name} added for ${selectedStudent.firstName} to ${_formatDate(_selectedDay)}'),
            backgroundColor: Colors.purple,
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'View Week',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WeeklyCartScreen(
                      weekStartDate: _selectedDay,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    } else {
      // Add to day-of order with quantity, tagging student
      for (int i = 0; i < quantity; i++) {
        ref.read(dayOfOrderProvider.notifier).addItem(
          item,
          _selectedDay,
          studentId: selectedStudent.id,
          studentName: selectedStudent.fullName,
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(quantity > 1
              ? 'Added $quantity x ${item.name} for ${selectedStudent.firstName} to day-of order (${_formatDate(_selectedDay)})'
              : '${item.name} added for ${selectedStudent.firstName} to day-of order (${_formatDate(_selectedDay)})'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'View Orders',
            textColor: Colors.white,
            onPressed: _showDayOfOrdersDialog,
          ),
        ),
      );
    }
  }

  // Show day-of orders dialog
  void _showDayOfOrdersDialog() {
    final dayOfOrders = ref.read(dayOfOrderProvider);
    
    if (dayOfOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No day-of orders yet'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Day-of Orders (Pending Approval)'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: dayOfOrders.length,
            itemBuilder: (context, index) {
              final order = dayOfOrders[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange[100],
                  child: const Icon(Icons.pending_actions, color: Colors.orange),
                ),
                title: Text(order.menuItem.name),
                subtitle: Text(
                  '${_formatDate(order.selectedDate)} • Qty: ${order.quantity} • ${FormatUtils.currency(order.menuItem.price * order.quantity)}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    ref.read(dayOfOrderProvider.notifier).removeItem(order.id);
                    Navigator.pop(context);
                    _showDayOfOrdersDialog();
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitDayOfOrders();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit for Approval'),
          ),
        ],
      ),
    );
  }

  // Submit day-of orders for approval
  Future<void> _submitDayOfOrders() async {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: User not authenticated'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // TODO: Get student ID from parent - for now using parent ID
    final studentId = currentUser.uid;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      await ref.read(dayOfOrderProvider.notifier).submitForApproval(
            currentUser.uid,
            studentId,
          );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Day-of orders submitted for admin approval!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting orders: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Format date helper
  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  // Menu items grid with responsive columns
  Widget _buildMenuGrid(double screenWidth, Orientation orientation) {
    final menuItemsAsync = ref.watch(menuItemsProvider);
    final weeklyMenuAsync = ref.watch(weeklyMenuForDateProvider(_selectedDay));

    return menuItemsAsync.when(
      data: (allMenuItems) {
        return weeklyMenuAsync.when(
          data: (weeklyMenu) {
            // Check if menu is published
            if (weeklyMenu == null || !weeklyMenu.isPublished) {
              return _buildNoMenuPublishedState();
            }
            
            // Get scheduled items for selected day
            final filteredItems = _getScheduledItems(allMenuItems, weeklyMenu);

            if (filteredItems.isEmpty) {
              return _buildEmptyState();
            }

            return Semantics(
              label: 'Menu items list, ${filteredItems.length} items',
              child: ListView.separated(
                controller: _scrollController,
                padding: EdgeInsets.all(12.w),
                cacheExtent: 1000, // Preload items for smooth scrolling
                itemCount: filteredItems.length,
                separatorBuilder: (context, index) => SizedBox(height: 8.h),
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  return FoodCard(
                    item: item,
                    onTap: () {
                      setState(() {
                        _selectedItem = item;
                      });
                    },
                    onAddToCart: (quantity) => _addToOrder(item, quantity: quantity),
                  );
                },
              ),
            );
          },
          loading: () => const LoadingIndicator(text: 'Loading weekly menu...'),
          error: (error, stack) => Center(
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64.w, color: Colors.red),
                  SizedBox(height: 16.h),
                  Text(
                    'Error loading weekly menu',
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    error.toString(),
                    style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const LoadingIndicator(text: 'Loading menu...'),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64.sp,
              color: Theme.of(context).colorScheme.error,
            ),
            SizedBox(height: 16.h),
            Text(
              'Error loading menu',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              error.toString(),
              style: TextStyle(fontSize: 14.sp),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            ElevatedButton.icon(
              onPressed: () => ref.refresh(menuItemsProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[700],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Empty state when no items found
  Widget _buildEmptyState() {
    final isWeekend = _selectedDay.weekday == DateTime.saturday || _selectedDay.weekday == DateTime.sunday;
    final isReminderTime = _isReminderTime();
  final nextMonday = _getNextMonday();

    // Determine category-specific icon and label
    IconData icon;
    String categoryLabel;
    switch (_selectedCategory) {
      case 'Snack':
        icon = Icons.cookie;
        categoryLabel = 'snack';
        break;
      case 'Lunch':
        icon = Icons.lunch_dining;
        categoryLabel = 'lunch';
        break;
      case 'Drinks':
        icon = Icons.local_drink;
        categoryLabel = 'drink';
        break;
      default:
        icon = Icons.restaurant_menu;
        categoryLabel = 'menu item';
    }

    // Use weekend-specific icon if applicable
    if (isWeekend) {
      icon = Icons.event_busy;
    }

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80.sp,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16.h),
            Text(
              isWeekend
                  ? 'No Menu on Weekends'
                  : _searchQuery.isNotEmpty
                      ? 'No $categoryLabel found'
                      : 'No $categoryLabel scheduled',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              isWeekend
                  ? 'The canteen is closed on ${_selectedDay.weekday == DateTime.saturday ? 'Saturday' : 'Sunday'}. Menus are available Monday to Friday.'
                  : _searchQuery.isNotEmpty
                      ? 'Try adjusting your search or clearing filters'
                      : 'No ${_selectedCategory == 'All' ? '' : '$categoryLabel '}items scheduled for ${_selectedDay.year == ref.watch(dateRefreshProvider).year && _selectedDay.month == ref.watch(dateRefreshProvider).month && _selectedDay.day == ref.watch(dateRefreshProvider).day
                        ? 'today'
                        : DateFormat('EEEE, MMM d').format(_selectedDay)}',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            if (isReminderTime && isWeekend) ...[
              SizedBox(height: 24.h),
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.alarm, color: Colors.orange[700], size: 24.sp),
                        SizedBox(width: 8.w),
                        Text(
                          'Plan Next Week’s Meals!',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'Order by Sunday 8 PM to ensure your child’s meals are ready for the week. Check the menu for ${DateFormat('MMM d').format(nextMonday)}.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedDay = nextMonday;
                          _focusedDay = nextMonday;
                        });
                      },
                      icon: const Icon(Icons.skip_next),
                      label: Text('View ${DateFormat('MMM d').format(nextMonday)} Menu'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple[700],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: 24.h),
            // Suggestions
            if (_searchQuery.isEmpty) ...[
              // Only show suggestions if at least one suggestion card will be shown
              if (
                (!(isReminderTime && isWeekend) && isWeekend && _cartMode == 'weekly') ||
                (ref.watch(dateRefreshProvider).weekday != DateTime.saturday && ref.watch(dateRefreshProvider).weekday != DateTime.sunday) ||
                !isWeekend
              ) ...[
                Text(
                  'Suggestions:',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 12.h),
              ],
              // Only show "Check Next Monday" if the orange reminder card is NOT shown
              if (!(isReminderTime && isWeekend) && isWeekend && _cartMode == 'weekly')
                _buildSuggestionCard(
                  icon: Icons.skip_next,
                  title: 'Check Next Monday',
                  subtitle: 'See the menu for ${DateFormat('MMM d').format(nextMonday)}',
                  onTap: () {
                    setState(() {
                      _selectedDay = nextMonday;
                      _focusedDay = nextMonday;
                    });
                  },
                ),
              if (!(isReminderTime && isWeekend) && isWeekend && _cartMode == 'weekly')
                SizedBox(height: 8.h),
              // Show "Go to today" if today is a school day
        if (ref.watch(dateRefreshProvider).weekday != DateTime.saturday &&
          ref.watch(dateRefreshProvider).weekday != DateTime.sunday)
                _buildSuggestionCard(
                  icon: Icons.today,
                  title: 'Go to Today',
                            subtitle: 'Check today\'s menu for ${DateFormat('MMM d').format(ref.watch(dateRefreshProvider))}',
                  onTap: () {
                      setState(() {
                      final today = ref.read(dateRefreshProvider);
                      _selectedDay = DateTime(today.year, today.month, today.day);
                      _focusedDay = DateTime(today.year, today.month, today.day);
                    });
                  },
                ),
              if (!isWeekend) ...[
                SizedBox(height: 8.h),
                _buildSuggestionCard(
                  icon: Icons.category,
                  title: 'Try different categories',
                  subtitle: 'Browse Snacks, Lunch, or Drinks',
                  onTap: () {
                    final currentIdx = _categories.indexOf(_selectedCategory);
                    int nextIdx = currentIdx + 1;
                    if (nextIdx >= _categories.length) nextIdx = 1; // Skip 'All'
                    setState(() {
                      _selectedCategory = _categories[nextIdx];
                      _selectedItem = null;
                    });
                  },
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // Suggestion card helper
  Widget _buildSuggestionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            children: [
              Icon(icon, color: Colors.purple[700], size: 32.sp),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  // Empty state when menu is not published
  Widget _buildNoMenuPublishedState() {
    final isReminderTime = _isReminderTime();
    final nextMonday = _getNextMonday();
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(48.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: 80.w,
              color: Colors.purple[200],
            ),
            SizedBox(height: 24.h),
            Text(
              'No Menu Published',
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
                color: Colors.purple[700],
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'The weekly menu for ${DateFormat('MMM d, yyyy').format(_selectedDay)} hasn\'t been published yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.sp,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 16.h),
            Text(
            _selectedDay.difference(ref.read(dateRefreshProvider)).inDays.abs() < 7
                  ? '📢 Menu publishing soon! Check back in a few hours.'
                  : '📅 Plan ahead: Advance orders open when next week\'s menu is published (usually by Sunday 8 PM).',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[500],
                height: 1.4,
              ),
            ),
            if (isReminderTime) ...[
              SizedBox(height: 24.h),
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.alarm, color: Colors.orange[700], size: 24.sp),
                        SizedBox(width: 8.w),
                        Text(
                          'Plan Next Week’s Meals!',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'Order by Sunday 8 PM to ensure your child’s meals are ready for the week. Check the menu for ${DateFormat('MMM d').format(nextMonday)}.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedDay = nextMonday;
                          _focusedDay = nextMonday;
                        });
                      },
                      icon: const Icon(Icons.skip_next),
                      label: Text('View ${DateFormat('MMM d').format(nextMonday)} Menu'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple[700],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: 32.h),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                          final today = ref.read(dateRefreshProvider);
                          _selectedDay = DateTime(today.year, today.month, today.day);
                          _focusedDay = DateTime(today.year, today.month, today.day);
                        });
                  },
                  icon: const Icon(Icons.today),
                  label: const Text('Go to Today'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purple[700],
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                  ),
                ),
                SizedBox(width: 12.w),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedDay = nextMonday;
                      _focusedDay = nextMonday;
                    });
                  },
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Next Week'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[700],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                  ),
                ),
              ],
            ),
            SizedBox(height: 32.h),
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.purple[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.purple[700], size: 24.sp),
                      SizedBox(width: 8.w),
                      Text(
                        'Pro Tip',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple[700],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Order by Sunday evening to ensure your child\'s meals are prepared. '
                    'Same-day "pahabol" orders require admin approval and are subject to availability.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Warning for invalid order mode date
  Widget _buildDateModeWarning() {
    // Show info when user selects today (day-of order) AND in daily mode
    // Don't show in weekly bundle mode
    if (_orderMode == 'dayOf' && _cartMode == 'daily') {
      return Container(
        margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          border: Border.all(color: Colors.orange[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange[700], size: 20.sp),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                '📢 Same-day order requires admin approval',
                style: TextStyle(
                  color: Colors.orange[900],
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return const SizedBox.shrink();
  }
}
