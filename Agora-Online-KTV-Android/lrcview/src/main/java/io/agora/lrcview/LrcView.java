/*
 * Copyright (C) 2017 wangchenyan
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
 * except in compliance with the License. You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software distributed under the
 * License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

package io.agora.lrcview;

import android.annotation.SuppressLint;
import android.content.Context;
import android.content.res.TypedArray;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Rect;
import android.os.AsyncTask;
import android.os.Looper;
import android.text.Layout;
import android.text.StaticLayout;
import android.text.TextPaint;
import android.text.TextUtils;
import android.text.format.DateUtils;
import android.util.AttributeSet;
import android.view.View;

import java.io.File;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

@SuppressLint("StaticFieldLeak")
public class LrcView extends View {
    private static final String TAG = "LrcView";
    private static final long ADJUST_DURATION = 100;
    private static final long TIMELINE_KEEP_TIME = 4 * DateUtils.SECOND_IN_MILLIS;

    private List<LrcEntry> mLrcEntryList = new ArrayList<>();
    private TextPaint mLrcPaint = new TextPaint();
    private TextPaint mBgLrcPaint = new TextPaint();
    private int mNormalTextColor;
    private float mNormalTextSize;
    private int mCurrentTextColor;
    private float mCurrentTextSize;
    private float mDividerHeight;
    private String mDefaultLabel;
    private float mLrcPadding;
    private int mCurrentLine;
    private Object mFlag;
    /**
     * 歌词显示位置，靠左/居中/靠右
     */
    private int mTextGravity;

    private boolean mNewLine = true;
    private Bitmap mFgText1 = null;
    // private Bitmap mFgText2 = null;
    private Bitmap mBgText1 = null;
    // private Bitmap mBgText2 = null;
    private Canvas mFgTextCanvas1 = null;
    private Canvas mBgTextCanvas1 = null;
    private Rect mTextBmpRect = new Rect();
    private Rect mTextRenderRect = new Rect();
    private int mTextHeight = 0;
    private long mCurrentTime = 0;
    private long mTotalDuration = 0;

    public LrcView(Context context) {
        this(context, null);
    }

    public LrcView(Context context, AttributeSet attrs) {
        this(context, attrs, 0);
    }

    public LrcView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        init(attrs);
    }

    private void init(AttributeSet attrs) {
        TypedArray ta = getContext().obtainStyledAttributes(attrs, R.styleable.LrcView);
        mCurrentTextSize = ta.getDimension(R.styleable.LrcView_lrcTextSize, getResources().getDimension(R.dimen.lrc_text_size));
        mNormalTextSize = ta.getDimension(R.styleable.LrcView_lrcNormalTextSize, getResources().getDimension(R.dimen.lrc_text_size));
        if (mNormalTextSize == 0) {
            mNormalTextSize = mCurrentTextSize;
        }

        mDividerHeight = ta.getDimension(R.styleable.LrcView_lrcDividerHeight, getResources().getDimension(R.dimen.lrc_divider_height));
        mNormalTextColor = ta.getColor(R.styleable.LrcView_lrcNormalTextColor, getResources().getColor(R.color.lrc_normal_text_color));
        mCurrentTextColor = ta.getColor(R.styleable.LrcView_lrcCurrentTextColor, getResources().getColor(R.color.lrc_current_text_color));
        mDefaultLabel = ta.getString(R.styleable.LrcView_lrcLabel);
        mDefaultLabel = TextUtils.isEmpty(mDefaultLabel) ? getContext().getString(R.string.lrc_label) : mDefaultLabel;
        mLrcPadding = ta.getDimension(R.styleable.LrcView_lrcPadding, 0);
        mTextGravity = ta.getInteger(R.styleable.LrcView_lrcTextGravity, LrcEntry.GRAVITY_CENTER);

        ta.recycle();

        mLrcPaint.setAntiAlias(true);
        mLrcPaint.setTextSize(mCurrentTextSize);
        mLrcPaint.setTextAlign(Paint.Align.LEFT);
        mBgLrcPaint.setAntiAlias(true);
        mBgLrcPaint.setTextSize(mCurrentTextSize);
        mBgLrcPaint.setTextAlign(Paint.Align.LEFT);
    }

    public void setTotalDuration(long d) {
        mTotalDuration = d;
    }

    /**
     * 设置非当前行歌词字体颜色
     */
    public void setNormalColor(int normalColor) {
        mNormalTextColor = normalColor;
        postInvalidate();
    }

    /**
     * 普通歌词文本字体大小
     */
    public void setNormalTextSize(float size) {
        mNormalTextSize = size;
    }

    /**
     * 当前歌词文本字体大小
     */
    public void setCurrentTextSize(float size) {
        mCurrentTextSize = size;
    }

    /**
     * 设置当前行歌词的字体颜色
     */
    public void setCurrentColor(int currentColor) {
        mCurrentTextColor = currentColor;
        postInvalidate();
    }

    /**
     * 设置歌词为空时屏幕中央显示的文字，如“暂无歌词”
     */
    public void setLabel(String label) {
        runOnUi(() -> {
            mDefaultLabel = label;
            invalidate();
        });
    }

    /**
     * 加载歌词文件
     *
     * @param lrcFile 歌词文件
     */
    public void loadLrc(File lrcFile) {
        loadLrc(lrcFile, null);
    }

    /**
     * 加载双语歌词文件，两种语言的歌词时间戳需要一致
     *
     * @param mainLrcFile   第一种语言歌词文件
     * @param secondLrcFile 第二种语言歌词文件
     */
    public void loadLrc(File mainLrcFile, File secondLrcFile) {
        runOnUi(() -> {
            reset();

            StringBuilder sb = new StringBuilder("file://");
            sb.append(mainLrcFile.getPath());
            if (secondLrcFile != null) {
                sb.append("#").append(secondLrcFile.getPath());
            }
            String flag = sb.toString();
            setFlag(flag);
            new AsyncTask<File, Integer, List<LrcEntry>>() {
                @Override
                protected List<LrcEntry> doInBackground(File... params) {
                    return LrcUtils.parseLrc(params);
                }

                @Override
                protected void onPostExecute(List<LrcEntry> lrcEntries) {
                    if (getFlag() == flag) {
                        onLrcLoaded(lrcEntries);
                        setFlag(null);
                    }
                }
            }.execute(mainLrcFile, secondLrcFile);
        });
    }

    /**
     * 加载歌词文本
     *
     * @param lrcText 歌词文本
     */
    public void loadLrc(String lrcText) {
        loadLrc(lrcText, null);
    }

    /**
     * 加载双语歌词文本，两种语言的歌词时间戳需要一致
     *
     * @param mainLrcText   第一种语言歌词文本
     * @param secondLrcText 第二种语言歌词文本
     */
    public void loadLrc(String mainLrcText, String secondLrcText) {
        runOnUi(() -> {
            reset();

            StringBuilder sb = new StringBuilder("file://");
            sb.append(mainLrcText);
            if (secondLrcText != null) {
                sb.append("#").append(secondLrcText);
            }
            String flag = sb.toString();
            setFlag(flag);
            new AsyncTask<String, Integer, List<LrcEntry>>() {
                @Override
                protected List<LrcEntry> doInBackground(String... params) {
                    return LrcUtils.parseLrc(params);
                }

                @Override
                protected void onPostExecute(List<LrcEntry> lrcEntries) {
                    if (getFlag() == flag) {
                        onLrcLoaded(lrcEntries);
                        setFlag(null);
                    }
                }
            }.execute(mainLrcText, secondLrcText);
        });
    }

    /**
     * 加载在线歌词，默认使用 utf-8 编码
     *
     * @param lrcUrl 歌词文件的网络地址
     */
    public void loadLrcByUrl(String lrcUrl) {
        loadLrcByUrl(lrcUrl, "utf-8");
    }

    /**
     * 加载在线歌词
     *
     * @param lrcUrl  歌词文件的网络地址
     * @param charset 编码格式
     */
    public void loadLrcByUrl(String lrcUrl, String charset) {
        String flag = "url://" + lrcUrl;
        setFlag(flag);
        new AsyncTask<String, Integer, String>() {
            @Override
            protected String doInBackground(String... params) {
                return LrcUtils.getContentFromNetwork(params[0], params[1]);
            }

            @Override
            protected void onPostExecute(String lrcText) {
                if (getFlag() == flag) {
                    loadLrc(lrcText);
                }
            }
        }.execute(lrcUrl, charset);
    }

    /**
     * 歌词是否有效
     *
     * @return true，如果歌词有效，否则false
     */
    public boolean hasLrc() {
        return !mLrcEntryList.isEmpty();
    }

    /**
     * 刷新歌词
     *
     * @param time 当前播放时间
     */
    public void updateTime(long time) {
        if (!hasLrc()) {
            return;
        }
        mCurrentTime = time;

        int line = findShowLine(time);
        if (line != mCurrentLine) {
            mNewLine = true;
            mCurrentLine = line;
        }
        invalidate();
    }

    @Override
    protected void onLayout(boolean changed, int left, int top, int right, int bottom) {
        super.onLayout(changed, left, top, right, bottom);
        if (changed) {
            //TODO: new bitmap and cavas
            int w = right - left;
            int h = bottom - top;

            if (mFgText1 == null) {
                mFgText1 = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888);
                mFgTextCanvas1 = new Canvas(mFgText1);
            }

            if (mBgText1 == null) {
                mBgText1 = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888);
                mBgTextCanvas1 = new Canvas(mBgText1);
            }

            // initPlayDrawable();
            initEntryList();
            if (hasLrc()) {
                // smoothScrollTo(mCurrentLine, 0L);
                updateTime(0L);
            }
        }
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);

        // 无歌词文件
        if (!hasLrc()) {
            mLrcPaint.setColor(mCurrentTextColor);
            @SuppressLint("DrawAllocation")
            StaticLayout staticLayout = new StaticLayout(mDefaultLabel, mLrcPaint,
                    (int) getLrcWidth(), Layout.Alignment.ALIGN_CENTER, 1f, 0f, false);
            drawText(canvas, staticLayout, (getHeight() - staticLayout.getHeight()) / 2F);
            return;
        }

        LrcEntry curEntry = mLrcEntryList.get(mCurrentLine);
        int h = curEntry.getHeight();

        if (mNewLine) {
            // clear bitmap
            mFgText1.eraseColor(0);
            mBgText1.eraseColor(0);

            //TODO: draw text on the bitmap
            mLrcPaint.setColor(mCurrentTextColor);
            curEntry.drawFg(mFgTextCanvas1);

            mBgLrcPaint.setColor(mNormalTextColor);
            mBgTextCanvas1.save();
            int curY = 0;
            for (int i = mCurrentLine; i < mLrcEntryList.size(); ++i) {
                LrcEntry line = mLrcEntryList.get(i);
                if (curY + line.getHeight() > mBgTextCanvas1.getHeight() &&
                        i > (mCurrentLine + 1))
                    break;
                line.drawBg(mBgTextCanvas1);
                mBgTextCanvas1.translate(0, line.getHeight() + mDividerHeight);
                curY += line.getHeight() + mDividerHeight;
            }
            mBgTextCanvas1.restore();
            mTextHeight = curY - (int) mDividerHeight;

            mNewLine = false;
        }

        // canvas.translate(0, getHeight() - h);
        //TODO: draw bg text to the canvas
        mTextBmpRect.left = 0;
        mTextBmpRect.top = 0;
        mTextBmpRect.right = (int) getLrcWidth();
        mTextBmpRect.bottom = mTextHeight;

        mTextRenderRect.left = (int) mLrcPadding;
        mTextRenderRect.top = 0;
        mTextRenderRect.right = getWidth() - (int) mLrcPadding;
        mTextRenderRect.bottom = mTextHeight;
        canvas.drawBitmap(mBgText1, mTextBmpRect, mTextRenderRect, null);

        //TODO: get fg text draw rect by current timestamp
        Rect[] drawRects = curEntry.getDrawRectByTime(mCurrentTime);

        // canvas.translate(0, getHeight() - h);
        //TODO: draw fg text to the canvas
        int xOffset = (int) mLrcPadding;
        int yOffset = 0;
        for (Rect dr : drawRects) {
            if (dr.left == dr.right)
                continue;

            mTextRenderRect.left = xOffset + dr.left;
            mTextRenderRect.top = yOffset + dr.top;
            mTextRenderRect.right = xOffset + dr.right;
            mTextRenderRect.bottom = yOffset + dr.bottom;
            canvas.drawBitmap(mFgText1, dr, mTextRenderRect, null);
        }
    }

    /**
     * 画一行歌词
     *
     * @param y 歌词中心 Y 坐标
     */
    private void drawText(Canvas canvas, StaticLayout staticLayout, float y) {
        canvas.save();
        canvas.translate(mLrcPadding, y - (staticLayout.getHeight() >> 1));
        staticLayout.draw(canvas);
        canvas.restore();
    }

    private void onLrcLoaded(List<LrcEntry> entryList) {
        if (entryList != null && !entryList.isEmpty()) {
            mLrcEntryList.addAll(entryList);
        }

        Collections.sort(mLrcEntryList);

        initEntryList();
        invalidate();
    }

    private void initEntryList() {
        if (!hasLrc() || getWidth() == 0) {
            return;
        }

        for (LrcEntry lrcEntry : mLrcEntryList) {
            lrcEntry.init(mLrcPaint, mBgLrcPaint, (int) getLrcWidth(), mTextGravity);
        }

        LrcEntry lastEntry = null;
        if (mLrcEntryList.size() > 0 && mTotalDuration > 0) {
            lastEntry = mLrcEntryList.get(mLrcEntryList.size() - 1);
            lastEntry.setDuration(mTotalDuration - lastEntry.getTime());
        }
        // mOffset = getHeight() / 2;
    }

    public void reset() {
        mLrcEntryList.clear();
        mCurrentLine = 0;
        mNewLine = true;
        mCurrentTime = 0;
        invalidate();
    }

    /**
     * 二分法查找当前时间应该显示的行数（最后一个 <= time 的行数）
     */
    private int findShowLine(long time) {
        int left = 0;
        int right = mLrcEntryList.size();
        while (left <= right) {
            int middle = (left + right) / 2;
            long middleTime = mLrcEntryList.get(middle).getTime();

            if (time < middleTime) {
                right = middle - 1;
            } else {
                if (middle + 1 >= mLrcEntryList.size() || time < mLrcEntryList.get(middle + 1).getTime()) {
                    return middle;
                }

                left = middle + 1;
            }
        }

        return 0;
    }

    /**
     * 获取歌词宽度
     */
    private float getLrcWidth() {
        return getWidth() - mLrcPadding * 2;
    }

    /**
     * 在主线程中运行
     */
    private void runOnUi(Runnable r) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            r.run();
        } else {
            post(r);
        }
    }

    private Object getFlag() {
        return mFlag;
    }

    private void setFlag(Object flag) {
        this.mFlag = flag;
    }
}