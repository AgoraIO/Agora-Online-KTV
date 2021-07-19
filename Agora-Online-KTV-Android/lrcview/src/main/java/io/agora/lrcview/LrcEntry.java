package io.agora.lrcview;

import android.graphics.Canvas;
import android.graphics.Rect;
import android.text.Layout;
import android.text.StaticLayout;
import android.text.TextPaint;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import io.agora.lrcview.bean.IEntry;

/**
 * 处理每一行歌词
 *
 * @author chenhengfei(Aslanchen)
 * @date 2021/7/6
 */
public class LrcEntry {
    private static final String TAG = "LrcEntry";
    private StaticLayout mLayoutBG;//背景文字
    private StaticLayout mLayoutFG;//前排高亮文字

    private Rect[] drawRects;//控制进度

    private Rect[] textRectWords;//歌词每个字信息
    private Rect[] textRectDisplayLines;//每一行显示的歌词

    private IEntry mIEntry;//数据源

    public enum Gravity {
        CENTER(0), LEFT(1), RIGHT(2);

        int value = 0;

        Gravity(int value) {
            this.value = value;
        }

        static Gravity parse(int value) {
            if (value == 0) {
                return CENTER;
            } else if (value == 1) {
                return LEFT;
            } else if (value == 2) {
                return RIGHT;
            } else {
                return CENTER;
            }
        }
    }

    public LrcEntry(IEntry mIEntry) {
        this.mIEntry = mIEntry;
    }

    void init(@NonNull TextPaint mTextPaintBG, int width, Gravity gravity) {
        this.init(null, mTextPaintBG, width, gravity);
    }

    void init(@Nullable TextPaint mTextPaintFG, @NonNull TextPaint mTextPaintBG, int width, Gravity gravity) {
        Layout.Alignment align;
        switch (gravity) {
            case LEFT:
                align = Layout.Alignment.ALIGN_NORMAL;
                break;

            default:
            case CENTER:
                align = Layout.Alignment.ALIGN_CENTER;
                break;
            case RIGHT:
                align = Layout.Alignment.ALIGN_OPPOSITE;
                break;
        }

        StringBuilder sb = new StringBuilder();
        IEntry.Tone[] tones = mIEntry.getTones();
        textRectWords = new Rect[tones.length];
        for (int i = 0; i < tones.length; i++) {
            IEntry.Tone tone = tones[i];
            Rect rect = new Rect();
            textRectWords[i] = rect;
            String s = tone.word;
            if (tone.lang != IEntry.Lang.Chinese) {
                s = s + " ";
            }
            sb.append(s);
            mTextPaintBG.getTextBounds(s, 0, s.length(), rect);
        }

        String text = sb.toString();
        if (mTextPaintFG != null) {
            mLayoutFG = new StaticLayout(text, mTextPaintFG, width, align, 1f, 0f, false);
        }
        mLayoutBG = new StaticLayout(text, mTextPaintBG, width, align, 1f, 0f, false);

        int totalLine = mLayoutBG.getLineCount();
        textRectDisplayLines = new Rect[totalLine];
        drawRects = new Rect[totalLine];
        for (int i = 0; i < totalLine; i++) {
            Rect mRect = new Rect();
            mLayoutBG.getLineBounds(i, mRect);
            mRect.left = (int) mLayoutBG.getLineLeft(i);
            mRect.right = (int) mLayoutBG.getLineRight(i);

            textRectDisplayLines[i] = mRect;
            drawRects[i] = new Rect(mRect);
        }
    }

    int getHeight() {
        if (mLayoutBG == null) {
            return 0;
        }
        return mLayoutBG.getHeight();
    }

    void draw(Canvas canvas) {
        mLayoutBG.draw(canvas);
    }

    void drawFG(Canvas canvas) {
        mLayoutFG.draw(canvas);
    }

    Rect[] getDrawRectByTime(long time) {
        int doneLen = 0;
        float curLen = 0f;

        IEntry.Tone[] tones = mIEntry.getTones();
        for (int i = 0; i < tones.length; i++) {
            IEntry.Tone tone = tones[i];
            int wordLen = textRectWords[i].right - textRectWords[i].left;

            if (time > tone.end) {
                doneLen = doneLen + wordLen;
            } else {
                float percent = (time - tone.begin) / (float) (tone.end - tone.begin);
                curLen = wordLen * percent;
                break;
            }
        }

        int showLen = (int) (doneLen + curLen);
        for (int i = 0; i < mLayoutFG.getLineCount(); i++) {
            int curLineWidth = textRectDisplayLines[i].right - textRectDisplayLines[i].left;
            drawRects[i].left = textRectDisplayLines[i].left;
            drawRects[i].right = textRectDisplayLines[i].right;
            if (curLineWidth > showLen) {
                drawRects[i].right = drawRects[i].left + showLen;
                showLen = 0;
            } else {
                showLen -= curLineWidth;
            }
        }

        return drawRects;
    }
}
