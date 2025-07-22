-- 更新 user_profiles 表，添加 user_id 欄位
ALTER TABLE public.user_profiles 
ADD COLUMN IF NOT EXISTS user_id VARCHAR(10) UNIQUE;

-- 創建唯一索引確保 user_id 不重複
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_profiles_user_id 
    ON public.user_profiles(user_id) WHERE user_id IS NOT NULL;

-- 創建好友關係表
CREATE TABLE IF NOT EXISTS public.friendships (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    requester_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    addressee_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (
        status IN ('pending', 'accepted', 'declined', 'blocked')
    ),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(requester_id, addressee_id)
);

-- 創建好友請求視圖（雙向關係）
CREATE OR REPLACE VIEW user_friends AS
SELECT DISTINCT
    CASE 
        WHEN f.requester_id = u.id THEN f.addressee_id
        ELSE f.requester_id
    END as friend_user_id,
    u.id as user_id,
    up_friend.user_id as friend_custom_id,
    up_friend.display_name as friend_display_name,
    up_friend.avatar_url as friend_avatar_url,
    f.status,
    f.created_at,
    f.updated_at
FROM public.friendships f
JOIN auth.users u ON (u.id = f.requester_id OR u.id = f.addressee_id)
JOIN public.user_profiles up_friend ON (
    up_friend.id = CASE 
        WHEN f.requester_id = u.id THEN f.addressee_id
        ELSE f.requester_id
    END
)
WHERE f.status = 'accepted';

-- 啟用 RLS
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;

-- RLS 政策：用戶只能看到自己相關的好友關係
CREATE POLICY "用戶只能管理自己的好友關係" ON public.friendships
    FOR ALL USING (
        auth.uid() = requester_id OR auth.uid() = addressee_id
    );

-- 創建更新時間觸發器
CREATE TRIGGER update_friendships_updated_at BEFORE UPDATE
    ON public.friendships FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 創建索引提升查詢效能
CREATE INDEX IF NOT EXISTS idx_friendships_requester 
    ON public.friendships(requester_id, status);
    
CREATE INDEX IF NOT EXISTS idx_friendships_addressee 
    ON public.friendships(addressee_id, status);

-- 創建生成 user_id 的函數
CREATE OR REPLACE FUNCTION generate_unique_user_id()
RETURNS TEXT AS $$
DECLARE
    new_user_id TEXT;
    counter INTEGER := 0;
BEGIN
    LOOP
        -- 生成6-8位隨機數字
        new_user_id := LPAD((RANDOM() * 99999999)::INTEGER::TEXT, 6, '0');
        
        -- 檢查是否已存在
        IF NOT EXISTS (
            SELECT 1 FROM public.user_profiles WHERE user_id = new_user_id
        ) THEN
            RETURN new_user_id;
        END IF;
        
        counter := counter + 1;
        -- 防止無限循環
        IF counter > 100 THEN
            RAISE EXCEPTION 'Unable to generate unique user_id after 100 attempts';
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 創建自動分配 user_id 的觸發器函數
CREATE OR REPLACE FUNCTION assign_user_id()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.user_id IS NULL THEN
        NEW.user_id := generate_unique_user_id();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 在 user_profiles 表上創建觸發器
CREATE OR REPLACE TRIGGER assign_user_id_trigger
    BEFORE INSERT ON public.user_profiles
    FOR EACH ROW EXECUTE FUNCTION assign_user_id();

-- 為現有用戶分配 user_id（如果沒有的話）
UPDATE public.user_profiles 
SET user_id = generate_unique_user_id() 
WHERE user_id IS NULL;

-- 創建搜尋用戶的函數
CREATE OR REPLACE FUNCTION search_users_by_id(search_user_id TEXT)
RETURNS TABLE(
    id UUID,
    user_id TEXT,
    display_name TEXT,
    avatar_url TEXT,
    bio TEXT,
    is_friend BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        up.id,
        up.user_id,
        up.display_name,
        up.avatar_url,
        up.bio,
        EXISTS(
            SELECT 1 FROM public.friendships f 
            WHERE (
                (f.requester_id = auth.uid() AND f.addressee_id = up.id) OR
                (f.addressee_id = auth.uid() AND f.requester_id = up.id)
            ) AND f.status = 'accepted'
        ) as is_friend
    FROM public.user_profiles up
    WHERE up.user_id = search_user_id
    AND up.id != auth.uid(); -- 排除自己
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 創建發送好友請求的函數
CREATE OR REPLACE FUNCTION send_friend_request(target_user_id TEXT)
RETURNS JSON AS $$
DECLARE
    target_uuid UUID;
    result JSON;
BEGIN
    -- 查找目標用戶的 UUID
    SELECT id INTO target_uuid 
    FROM public.user_profiles 
    WHERE user_id = target_user_id;
    
    IF target_uuid IS NULL THEN
        RETURN json_build_object(
            'success', false, 
            'message', '找不到指定的用戶'
        );
    END IF;
    
    -- 檢查是否已經是好友或已有請求
    IF EXISTS(
        SELECT 1 FROM public.friendships 
        WHERE (
            (requester_id = auth.uid() AND addressee_id = target_uuid) OR
            (requester_id = target_uuid AND addressee_id = auth.uid())
        )
    ) THEN
        RETURN json_build_object(
            'success', false, 
            'message', '已經發送過好友請求或已經是好友'
        );
    END IF;
    
    -- 插入好友請求
    INSERT INTO public.friendships (requester_id, addressee_id, status)
    VALUES (auth.uid(), target_uuid, 'pending');
    
    RETURN json_build_object(
        'success', true, 
        'message', '好友請求已發送'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 創建接受好友請求的函數
CREATE OR REPLACE FUNCTION accept_friend_request(requester_user_id TEXT)
RETURNS JSON AS $$
DECLARE
    requester_uuid UUID;
BEGIN
    -- 查找請求者的 UUID
    SELECT id INTO requester_uuid 
    FROM public.user_profiles 
    WHERE user_id = requester_user_id;
    
    IF requester_uuid IS NULL THEN
        RETURN json_build_object(
            'success', false, 
            'message', '找不到指定的用戶'
        );
    END IF;
    
    -- 更新好友請求狀態
    UPDATE public.friendships 
    SET status = 'accepted', updated_at = NOW()
    WHERE requester_id = requester_uuid 
    AND addressee_id = auth.uid() 
    AND status = 'pending';
    
    IF FOUND THEN
        RETURN json_build_object(
            'success', true, 
            'message', '已接受好友請求'
        );
    ELSE
        RETURN json_build_object(
            'success', false, 
            'message', '找不到待處理的好友請求'
        );
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 添加註釋
COMMENT ON TABLE public.friendships IS '好友關係表';
COMMENT ON FUNCTION search_users_by_id(TEXT) IS '根據 user_id 搜尋用戶';
COMMENT ON FUNCTION send_friend_request(TEXT) IS '發送好友請求';
COMMENT ON FUNCTION accept_friend_request(TEXT) IS '接受好友請求';