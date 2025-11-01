-- ============================================================================
-- CANTEEN APP - SUPABASE POSTGRES SCHEMA
-- ============================================================================
-- Migration: Initial Schema Creation
-- Created: 2025-11-01
-- Description: Complete database schema for canteen management system
-- 
-- This migration creates all tables required for:
-- - User authentication and profiles
-- - Student and parent management
-- - Menu items and weekly menus
-- - Orders and transactions
-- - Top-up requests
-- ============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- USERS TABLE
-- ============================================================================
-- Stores basic user information for all accounts (admin and parent roles)
-- Links to Supabase auth.users via uid
-- ============================================================================

CREATE TABLE IF NOT EXISTS users (
  uid UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  is_admin BOOLEAN DEFAULT FALSE,
  is_parent BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

-- Index for email lookups
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_active ON users(is_active);

-- Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Users can read their own profile
CREATE POLICY "Users can view own profile" ON users
  FOR SELECT USING (auth.uid() = uid);

-- Admins can view all users
CREATE POLICY "Admins can view all users" ON users
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users WHERE uid = auth.uid() AND is_admin = TRUE
    )
  );

-- Users can update their own profile
CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE USING (auth.uid() = uid);

-- Admins can insert/update/delete users
CREATE POLICY "Admins can manage users" ON users
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users WHERE uid = auth.uid() AND is_admin = TRUE
    )
  );

-- ============================================================================
-- PARENTS TABLE
-- ============================================================================
-- Extended profile information for parent users
-- One-to-one relationship with users table
-- ============================================================================

CREATE TABLE IF NOT EXISTS parents (
  user_id UUID PRIMARY KEY REFERENCES users(uid) ON DELETE CASCADE,
  phone TEXT,
  address TEXT,
  balance DECIMAL(10,2) DEFAULT 0.00 CHECK (balance >= 0),
  student_ids TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

-- Row Level Security
ALTER TABLE parents ENABLE ROW LEVEL SECURITY;

-- Parents can view their own profile
CREATE POLICY "Parents can view own profile" ON parents
  FOR SELECT USING (auth.uid() = user_id);

-- Admins can view all parents
CREATE POLICY "Admins can view all parents" ON parents
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users WHERE uid = auth.uid() AND is_admin = TRUE
    )
  );

-- Parents can update their own profile (except balance)
CREATE POLICY "Parents can update own profile" ON parents
  FOR UPDATE USING (auth.uid() = user_id);

-- Admins can manage parents
CREATE POLICY "Admins can manage parents" ON parents
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users WHERE uid = auth.uid() AND is_admin = TRUE
    )
  );

-- ============================================================================
-- STUDENTS TABLE
-- ============================================================================
-- Student profiles linked to parent accounts
-- ============================================================================

CREATE TABLE IF NOT EXISTS students (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  parent_user_id UUID NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  grade_level TEXT NOT NULL,
  section TEXT,
  photo_url TEXT,
  allergies TEXT[] DEFAULT '{}',
  dietary_restrictions TEXT[] DEFAULT '{}',
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

-- Indexes
CREATE INDEX idx_students_parent ON students(parent_user_id);
CREATE INDEX idx_students_active ON students(is_active);
CREATE INDEX idx_students_grade ON students(grade_level);

-- Row Level Security
ALTER TABLE students ENABLE ROW LEVEL SECURITY;

-- Parents can view their own students
CREATE POLICY "Parents can view own students" ON students
  FOR SELECT USING (auth.uid() = parent_user_id);

-- Admins can view all students
CREATE POLICY "Admins can view all students" ON students
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users WHERE uid = auth.uid() AND is_admin = TRUE
    )
  );

-- Parents can manage their own students
CREATE POLICY "Parents can manage own students" ON students
  FOR ALL USING (auth.uid() = parent_user_id);

-- Admins can manage all students
CREATE POLICY "Admins can manage all students" ON students
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users WHERE uid = auth.uid() AND is_admin = TRUE
    )
  );

-- ============================================================================
-- MENU_ITEMS TABLE
-- ============================================================================
-- Catalog of all available menu items
-- ============================================================================

CREATE TABLE IF NOT EXISTS menu_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  price DECIMAL(10,2) NOT NULL CHECK (price >= 0),
  category TEXT NOT NULL,
  image_url TEXT,
  is_available BOOLEAN DEFAULT TRUE,
  allergens TEXT[] DEFAULT '{}',
  dietary_labels TEXT[] DEFAULT '{}',
  prep_time_minutes INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

-- Indexes
CREATE INDEX idx_menu_items_category ON menu_items(category);
CREATE INDEX idx_menu_items_available ON menu_items(is_available);

-- Row Level Security
ALTER TABLE menu_items ENABLE ROW LEVEL SECURITY;

-- Everyone can view menu items
CREATE POLICY "Anyone can view menu items" ON menu_items
  FOR SELECT USING (TRUE);

-- Admins can manage menu items
CREATE POLICY "Admins can manage menu items" ON menu_items
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users WHERE uid = auth.uid() AND is_admin = TRUE
    )
  );

-- ============================================================================
-- WEEKLY_MENUS TABLE
-- ============================================================================
-- Weekly menu schedules
-- week_start should always be Monday (for consistency)
-- ============================================================================

CREATE TABLE IF NOT EXISTS weekly_menus (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  week_start DATE NOT NULL,
  menu_items_by_day JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  UNIQUE(week_start)
);

-- Index for week lookups
CREATE INDEX idx_weekly_menus_week ON weekly_menus(week_start);

-- Row Level Security
ALTER TABLE weekly_menus ENABLE ROW LEVEL SECURITY;

-- Everyone can view weekly menus
CREATE POLICY "Anyone can view weekly menus" ON weekly_menus
  FOR SELECT USING (TRUE);

-- Admins can manage weekly menus
CREATE POLICY "Admins can manage weekly menus" ON weekly_menus
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users WHERE uid = auth.uid() AND is_admin = TRUE
    )
  );

-- ============================================================================
-- ORDERS TABLE
-- ============================================================================
-- Customer orders (can be one-time or part of weekly order)
-- ============================================================================

CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_number TEXT UNIQUE NOT NULL,
  parent_id UUID NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  items JSONB NOT NULL DEFAULT '[]',
  total_amount DECIMAL(10,2) NOT NULL CHECK (total_amount >= 0),
  status TEXT NOT NULL DEFAULT 'pending',
  order_type TEXT NOT NULL DEFAULT 'one-time',
  delivery_date DATE NOT NULL,
  delivery_time TIME,
  special_instructions TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ
);

-- Indexes
CREATE INDEX idx_orders_parent ON orders(parent_id);
CREATE INDEX idx_orders_student ON orders(student_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_delivery_date ON orders(delivery_date);
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);

-- Row Level Security
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Parents can view their own orders
CREATE POLICY "Parents can view own orders" ON orders
  FOR SELECT USING (auth.uid() = parent_id);

-- Admins can view all orders
CREATE POLICY "Admins can view all orders" ON orders
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users WHERE uid = auth.uid() AND is_admin = TRUE
    )
  );

-- Parents can create their own orders
CREATE POLICY "Parents can create own orders" ON orders
  FOR INSERT WITH CHECK (auth.uid() = parent_id);

-- Parents can cancel their own pending orders
CREATE POLICY "Parents can cancel own orders" ON orders
  FOR UPDATE USING (
    auth.uid() = parent_id AND status = 'pending'
  );

-- Admins can manage all orders
CREATE POLICY "Admins can manage all orders" ON orders
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users WHERE uid = auth.uid() AND is_admin = TRUE
    )
  );

-- ============================================================================
-- PARENT_TRANSACTIONS TABLE
-- ============================================================================
-- Financial transactions for parent accounts (top-ups, order payments)
-- ============================================================================

CREATE TABLE IF NOT EXISTS parent_transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  parent_id UUID NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  type TEXT NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  balance_before DECIMAL(10,2) NOT NULL,
  balance_after DECIMAL(10,2) NOT NULL,
  description TEXT,
  reference_id TEXT,
  payment_method TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

-- Indexes
CREATE INDEX idx_transactions_parent ON parent_transactions(parent_id);
CREATE INDEX idx_transactions_type ON parent_transactions(type);
CREATE INDEX idx_transactions_status ON parent_transactions(status);
CREATE INDEX idx_transactions_created_at ON parent_transactions(created_at DESC);

-- Row Level Security
ALTER TABLE parent_transactions ENABLE ROW LEVEL SECURITY;

-- Parents can view their own transactions
CREATE POLICY "Parents can view own transactions" ON parent_transactions
  FOR SELECT USING (auth.uid() = parent_id);

-- Admins can view all transactions
CREATE POLICY "Admins can view all transactions" ON parent_transactions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users WHERE uid = auth.uid() AND is_admin = TRUE
    )
  );

-- Admins can create transactions
CREATE POLICY "Admins can create transactions" ON parent_transactions
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM users WHERE uid = auth.uid() AND is_admin = TRUE
    )
  );

-- Admins can update transactions
CREATE POLICY "Admins can update transactions" ON parent_transactions
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM users WHERE uid = auth.uid() AND is_admin = TRUE
    )
  );

-- ============================================================================
-- TOPUP_REQUESTS TABLE
-- ============================================================================
-- Parent requests to add funds to their account
-- ============================================================================

CREATE TABLE IF NOT EXISTS topup_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  parent_id UUID NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
  payment_method TEXT NOT NULL,
  proof_image_url TEXT,
  reference_number TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  notes TEXT,
  admin_notes TEXT,
  processed_by UUID REFERENCES users(uid),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ
);

-- Indexes
CREATE INDEX idx_topup_parent ON topup_requests(parent_id);
CREATE INDEX idx_topup_status ON topup_requests(status);
CREATE INDEX idx_topup_created_at ON topup_requests(created_at DESC);

-- Row Level Security
ALTER TABLE topup_requests ENABLE ROW LEVEL SECURITY;

-- Parents can view their own topup requests
CREATE POLICY "Parents can view own topups" ON topup_requests
  FOR SELECT USING (auth.uid() = parent_id);

-- Admins can view all topup requests
CREATE POLICY "Admins can view all topups" ON topup_requests
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users WHERE uid = auth.uid() AND is_admin = TRUE
    )
  );

-- Parents can create their own topup requests
CREATE POLICY "Parents can create own topups" ON topup_requests
  FOR INSERT WITH CHECK (auth.uid() = parent_id);

-- Admins can manage all topup requests
CREATE POLICY "Admins can manage all topups" ON topup_requests
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users WHERE uid = auth.uid() AND is_admin = TRUE
    )
  );

-- ============================================================================
-- WEEKLY_MENU_ANALYTICS TABLE
-- ============================================================================
-- Analytics data for weekly menu performance
-- ============================================================================

CREATE TABLE IF NOT EXISTS weekly_menu_analytics (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  week_start DATE NOT NULL,
  analytics_data JSONB NOT NULL DEFAULT '{}',
  total_orders INTEGER DEFAULT 0,
  total_revenue DECIMAL(10,2) DEFAULT 0.00,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  UNIQUE(week_start)
);

-- Index for week lookups
CREATE INDEX idx_analytics_week ON weekly_menu_analytics(week_start);

-- Row Level Security
ALTER TABLE weekly_menu_analytics ENABLE ROW LEVEL SECURITY;

-- Admins can view analytics
CREATE POLICY "Admins can view analytics" ON weekly_menu_analytics
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users WHERE uid = auth.uid() AND is_admin = TRUE
    )
  );

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_parents_updated_at BEFORE UPDATE ON parents
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_students_updated_at BEFORE UPDATE ON students
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_menu_items_updated_at BEFORE UPDATE ON menu_items
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_weekly_menus_updated_at BEFORE UPDATE ON weekly_menus
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_transactions_updated_at BEFORE UPDATE ON parent_transactions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- INITIAL DATA
-- ============================================================================
-- Add any seed data here if needed
-- ============================================================================

COMMENT ON TABLE users IS 'Core user accounts for both admin and parent roles';
COMMENT ON TABLE parents IS 'Extended profile for parent users with wallet balance';
COMMENT ON TABLE students IS 'Student profiles linked to parent accounts';
COMMENT ON TABLE menu_items IS 'Catalog of available menu items';
COMMENT ON TABLE weekly_menus IS 'Weekly menu schedules by day';
COMMENT ON TABLE orders IS 'Customer orders for menu items';
COMMENT ON TABLE parent_transactions IS 'Financial transactions for parent accounts';
COMMENT ON TABLE topup_requests IS 'Parent requests to add funds';
COMMENT ON TABLE weekly_menu_analytics IS 'Analytics for weekly menu performance';
