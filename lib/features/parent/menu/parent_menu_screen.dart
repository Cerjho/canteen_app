import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../shared/utils/date_refresh_controller.dart';
import '../../../core/models/menu_item.dart';
import '../../../core/models/weekly_menu.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/selected_student_provider.dart';
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
  
  // Cart mode toggle removed; behavior is derived from selected date (today vs future)
  
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
    // If no menu exists, return empty list
    if (weeklyMenu == null) {
      return [];
    }
    
    // Get day name (e.g., "Monday")
    final dayName = DateFormat('EEEE').format(_selectedDay);
    
    // Get menu for this day
    final dayMenu = weeklyMenu.menuItemsByDay[dayName];
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
    // Show helpful tip when selecting today (day-of order)
    if (selected == today) {
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

    // Watch dateRefreshProvider to ensure rebuild when date changes
    ref.watch(dateRefreshProvider);

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

  // Orientation is checked within OrientationBuilder
    return ResponsiveBuilder(
      builder: (context, sizingInformation) {
        // Determine device type
        final deviceType = sizingInformation.deviceScreenType;
        final screenWidth = sizingInformation.screenSize.width;
        final isMobile = deviceType == DeviceScreenType.mobile;
        final isTablet = deviceType == DeviceScreenType.tablet;
        final isDesktop = deviceType == DeviceScreenType.desktop;
  // master-detail still handled inside OrientationBuilder

        return Scaffold(
          // Put back the top header AppBar for all layouts
          appBar: _buildAppBar(isMobile),
          body: SafeArea(
            child: Column(
              children: [
                studentChipSelector,
                Expanded(
                  child: OrientationBuilder(
                    builder: (context, orientation) {
                      final isMaster = isDesktop || (isTablet && orientation == Orientation.landscape);
                      if (isMaster) {
                        // Master-detail layout for desktop/tablet landscape
                        return _buildMasterDetailLayout(screenWidth, orientation);
                      }
                      // Single pane layout with collapsing header
                      return CustomScrollView(
                        controller: _scrollController,
                        slivers: [
                          _buildCollapsingSliverAppBar(isMobile),
                          _buildMenuSliver(screenWidth, orientation),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Bottom navigation is handled by parent_app.dart at the app level
          // Day-of submit FAB removed; today adds to Cart directly
          floatingActionButton: null,
        );
      },
    );
  }

  // Collapsing SliverAppBar containing calendar and search bar
  Widget _buildCollapsingSliverAppBar(bool isMobile) {
    // top Scaffold AppBar handles title now

  final double chipsHeight = isMobile ? 44.h : 48.h;
  // Shrink expanded height to hug content; add a little headroom to avoid clipping
  final bool isDayOf = _orderMode == 'dayOf';
  final double expandedHeight = isMobile
    ? (isDayOf ? 240.h : 196.h)
    : (isDayOf ? 270.h : 230.h);

    return SliverAppBar(
      pinned: true,
      floating: false,
      primary: false, // we have a top Scaffold AppBar already
      toolbarHeight: 0, // no internal toolbar to avoid double headers
      expandedHeight: expandedHeight,
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(chipsHeight),
        child: _buildCategoryChips(isMobile),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Material(
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCalendar(isMobile),
              _buildSearchBar(isMobile),
              _buildDateModeWarning(),
              // Small spacer to separate warning banner (if visible) from chips below
              SizedBox(height: isDayOf ? 10.h : 2.h),
            ],
          ),
        ),
      ),
    );
  }

  // AppBar with responsive design
  PreferredSizeWidget _buildAppBar(bool isMobile) {
    return AppBar(
      title: Text(
        'Canteen Menu',
        style: TextStyle(
          fontSize: isMobile ? 18.sp : 20.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        SizedBox(width: 8.w),
        _buildCartAction(isMobile),
        SizedBox(width: 8.w),
      ],
    );
  }

  // Shared Cart action with badge
  Widget _buildCartAction(bool isMobile) {
    final cartItemCount = ref.watch(cartItemCountProvider);
    final weeklyCartItemCount = ref.watch(weeklyCartItemCountProvider);
    final now = ref.watch(dateRefreshProvider);
    final today = DateTime(now.year, now.month, now.day);
    final isToday = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day) == today;
    final badgeCount = isToday ? cartItemCount : weeklyCartItemCount;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(Icons.shopping_cart, size: isMobile ? 22.sp : 24.sp),
          onPressed: () {
            final now = ref.read(dateRefreshProvider);
            final today = DateTime(now.year, now.month, now.day);
            final isToday = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day) == today;
            if (isToday) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CartScreen(),
                  fullscreenDialog: true,
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WeeklyCartScreen(weekStartDate: _selectedDay),
                  fullscreenDialog: true,
                ),
              );
            }
          },
          tooltip: 'Cart',
        ),
        if (badgeCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: IgnorePointer(
              ignoring: true, // ensure taps pass through to the cart button
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
          ),
      ],
    );
  }

  // Day-of approval flow removed in favor of today's cart

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
              // Calendar always visible; behavior derived by selected date
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

  // Single pane layout replaced by sliver-based layout in build()

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
      padding: EdgeInsets.fromLTRB(12.w, 6.h, 12.w, 2.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
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
      // Add a tiny top padding only when the day-of warning banner is visible
      padding: EdgeInsets.fromLTRB(8.w, _orderMode == 'dayOf' ? 4.h : 0, 8.w, 0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        // remove bottom border to tighten space with the list below
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

  // Add item to cart based on selected date (today -> daily cart, future -> weekly cart)
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
    final now = ref.read(dateRefreshProvider);
    final today = DateTime(now.year, now.month, now.day);
    final isToday = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day) == today;

    if (isToday) {
      // Add to daily cart
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
                MaterialPageRoute(
                  builder: (context) => const CartScreen(),
                  fullscreenDialog: true,
                ),
              );
            },
          ),
        ),
      );
    } else {
      // Add to weekly cart for selected date
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
                  builder: (context) => WeeklyCartScreen(weekStartDate: _selectedDay),
                  fullscreenDialog: true,
                ),
              );
            },
          ),
        ),
      );
    }
  }

  // Day-of dialog removed

  // Day-of submission removed

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
            // Check if menu exists
            if (weeklyMenu == null) {
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
                      _showAddToCartSheet(item);
                    },
                    onAddToCart: () => _showAddToCartSheet(item),
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

  // Sliver version of the menu list for collapsing layout
  Widget _buildMenuSliver(double screenWidth, Orientation orientation) {
    final menuItemsAsync = ref.watch(menuItemsProvider);
    final weeklyMenuAsync = ref.watch(weeklyMenuForDateProvider(_selectedDay));

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      sliver: SliverToBoxAdapter(
        child: menuItemsAsync.when(
          data: (allMenuItems) {
            return weeklyMenuAsync.when(
              data: (weeklyMenu) {
                if (weeklyMenu == null) {
                  return _buildNoMenuPublishedState();
                }
                final filteredItems = _getScheduledItems(allMenuItems, weeklyMenu);
                if (filteredItems.isEmpty) {
                  return _buildEmptyState();
                }
                // Use a normal ListView-like build via ListView inside SliverToBoxAdapter for simplicity
                return ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  controller: _scrollController,
                  itemCount: filteredItems.length,
                  separatorBuilder: (_, __) => SizedBox(height: 8.h),
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return FoodCard(
                      item: item,
                      onTap: () => _showAddToCartSheet(item),
                      onAddToCart: () => _showAddToCartSheet(item),
                    );
                  },
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
                      Text('Error loading weekly menu', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8.h),
                      Text(error.toString(), style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]), textAlign: TextAlign.center),
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
                Icon(Icons.error_outline, size: 64.sp, color: Theme.of(context).colorScheme.error),
                SizedBox(height: 16.h),
                Text('Error loading menu', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
                SizedBox(height: 8.h),
                Text(error.toString(), style: TextStyle(fontSize: 14.sp), textAlign: TextAlign.center),
                SizedBox(height: 16.h),
                ElevatedButton.icon(
                  onPressed: () => ref.refresh(menuItemsProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[700], foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  

  /// Bottom sheet to collect quantity, delivery time slot, and special instructions
  void _showAddToCartSheet(MenuItem item, {int prefillQuantity = 1}) {
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

  int qty = prefillQuantity.clamp(1, 20);
  // Delivery time rules: Lunch is fixed at 12:00; Snacks/Drinks can choose
  final bool isLunchItem = item.category.toLowerCase() == 'lunch';
  String? timeSlot = isLunchItem ? '12:00' : '09:00';
    final textController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(FormatUtils.currency(item.price), style: TextStyle(color: Colors.grey[700])),
                const SizedBox(height: 16),
                // Quantity
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w600)),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => setState(() => qty = (qty - 1).clamp(1, 20)),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('$qty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        IconButton(
                          onPressed: () => setState(() => qty = (qty + 1).clamp(1, 20)),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Delivery time
                const Text('Delivery time', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (isLunchItem) ...[
                  // Lunch has fixed delivery time
                  Wrap(
                    spacing: 8,
                    children: const [
                      Chip(label: Text('Lunch (12:00)')),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lunch items are delivered at 12:00 by default.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ] else ...[
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Morning (9:00)'),
                        selected: timeSlot == '09:00',
                        onSelected: (_) => setState(() => timeSlot = '09:00'),
                      ),
                      ChoiceChip(
                        label: const Text('Lunch (12:00)'),
                        selected: timeSlot == '12:00',
                        onSelected: (_) => setState(() => timeSlot = '12:00'),
                      ),
                      ChoiceChip(
                        label: const Text('Afternoon (14:00)'),
                        selected: timeSlot == '14:00',
                        onSelected: (_) => setState(() => timeSlot = '14:00'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                // Special instructions
                const Text('Special instructions', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: textController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'e.g., less spicy, no peanuts',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Add to Cart'),
                    onPressed: () {
                      final now = ref.read(dateRefreshProvider);
                      final today = DateTime(now.year, now.month, now.day);
                      final isToday = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day) == today;

                      if (isToday) {
                        // Add to daily cart
                        for (int i = 0; i < qty; i++) {
                          ref.read(cartProvider.notifier).addItem(
                                item,
                                studentId: selectedStudent.id,
                                studentName: selectedStudent.fullName,
                                deliveryTime: timeSlot,
                                specialInstructions: textController.text.trim().isEmpty ? null : textController.text.trim(),
                              );
                        }
                      } else {
                        // Add to weekly cart (advance ordering)
                        ref.read(weeklyCartProvider.notifier).addItemForDate(
                              item,
                              _selectedDay,
                              quantity: qty,
                              studentId: selectedStudent.id,
                              studentName: selectedStudent.fullName,
                              time: timeSlot,
                            );
                      }

                      Navigator.pop(context);
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text(
                              isToday
                                  ? 'Added $qty × ${item.name} (${timeSlot ?? '-'}) for ${selectedStudent.firstName}'
                                  : 'Added $qty × ${item.name} (${timeSlot ?? '-'}) for ${selectedStudent.firstName} to ${_formatDate(_selectedDay)}'),
                          backgroundColor: isToday ? Colors.green : Colors.purple,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
              if (!(isWeekend && isReminderTime)) ...[
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
              if (isWeekend && !isReminderTime)
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
              if (isWeekend && !isReminderTime)
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
    if (_orderMode == 'dayOf') {
      return Container(
        // Add a bit more breathing room below the banner so chips don't touch it
        margin: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 14.h),
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

// Sliver header delegate for sticky category chips (top-level)
// (removed) _ChipsHeaderDelegate: replaced by SliverAppBar.bottom PreferredSize with sticky chips
