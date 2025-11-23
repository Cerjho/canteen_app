-- Storage Bucket RLS Policies for "canteen" bucket
-- Allows admins and authenticated users to upload files to their respective folders
-- Public read access for all files

-- Enable RLS on storage.objects
ALTER TABLE IF EXISTS storage.objects ENABLE ROW LEVEL SECURITY;

-- Enable RLS on storage.buckets (if not already)
ALTER TABLE IF EXISTS storage.buckets ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- CANTEEN BUCKET POLICIES
-- ============================================================================

-- Public read access to all files in canteen bucket
CREATE POLICY "Public access to canteen bucket"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'canteen');

-- Allow admins to upload to menu-items folder
CREATE POLICY "Admins can upload menu items"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'canteen' 
    AND (storage.foldername(name))[1] = 'menu-items'
    AND COALESCE((auth.jwt()->>'is_admin')::boolean, false) = true
  );

-- Allow admins to upload to students folder
CREATE POLICY "Admins can upload students"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'canteen' 
    AND (storage.foldername(name))[1] = 'students'
    AND COALESCE((auth.jwt()->>'is_admin')::boolean, false) = true
  );

-- Allow admins to upload to parents folder
CREATE POLICY "Admins can upload parents"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'canteen' 
    AND (storage.foldername(name))[1] = 'parents'
    AND COALESCE((auth.jwt()->>'is_admin')::boolean, false) = true
  );

-- Allow admins to upload to topup-proofs folder
CREATE POLICY "Admins can upload topup proofs"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'canteen' 
    AND (storage.foldername(name))[1] = 'topup-proofs'
    AND COALESCE((auth.jwt()->>'is_admin')::boolean, false) = true
  );

-- Allow admins to delete from canteen bucket
CREATE POLICY "Admins can delete from canteen"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'canteen'
    AND COALESCE((auth.jwt()->>'is_admin')::boolean, false) = true
  );

-- Allow admins to update in canteen bucket
CREATE POLICY "Admins can update in canteen"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'canteen'
    AND COALESCE((auth.jwt()->>'is_admin')::boolean, false) = true
  )
  WITH CHECK (
    bucket_id = 'canteen'
    AND COALESCE((auth.jwt()->>'is_admin')::boolean, false) = true
  );

-- Note: Parents can upload payment proofs to topup-proofs folder
-- Allow parents to upload to topup-proofs folder (for their payment proofs)
CREATE POLICY "Parents can upload topup proofs"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'canteen' 
    AND (storage.foldername(name))[1] = 'topup-proofs'
    AND auth.uid() IS NOT NULL
  );
