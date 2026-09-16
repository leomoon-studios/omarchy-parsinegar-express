import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons

FocusScope {
    id: root

    required property var controller
    required property Typography typography
    readonly property color foreground: controller.foreground
    readonly property string fontFamily: typography.family
    readonly property bool rightToLeft: controller.uiLanguage === "fa" || controller.uiLanguage === "ar"
    readonly property Item focusItem: backButton
    signal backRequested()

    LayoutMirroring.enabled: rightToLeft
    LayoutMirroring.childrenInherit: true

    readonly property var englishSections: [
        {
            heading: "What ParsiNegar Express does",
            body: "Express prepares Persian, Arabic, Kurdish, Urdu, and Hebrew text for applications with incomplete shaping or bidirectional-text support. Enter or paste source text, choose a shaping profile and conversion mode, then select Convert. The result is copied to the clipboard.\n\nExpress changes character forms and visual order, not the font in the destination application."
        },
        {
            heading: "Quick start",
            body: "1. Enter or paste the source text. Pasting inserts plain text without website styling.\n2. In Settings, choose Persian/Arabic, Kurdish/Urdu, or Hebrew.\n3. Choose Unicode mode unless the destination requires a legacy Maryam-compatible font.\n4. Enable bidi visual ordering only if the destination lacks right-to-left support.\n5. Enable any needed Text tools and select Convert.\n6. Paste the result into the destination application."
        },
        {
            heading: "Conversion modes and direction",
            body: "Unicode mode is the normal choice for modern applications. Compatibility mode is for older applications that require legacy Maryam or LMN mappings and a matching font. Hebrew is Unicode-only.\n\nEach editor paragraph uses its first strong character for direction. Bidi visual ordering processes paragraphs separately and should remain off when the destination already handles bidirectional text correctly."
        },
        {
            heading: "Text tools",
            body: "Every Text tool has its own toggle. Enabled tools run together immediately before conversion, update the source text, and become one undoable edit. Reverse transformations cannot be enabled together.\n\nThe ZWNJ tool recognizes common Persian verbs, so it can repair می خواهم without blindly changing unrelated words such as میدان."
        },
        {
            heading: "Export SVG",
            body: "Export SVG creates editable vector curves from converted text. Choose a font, font size, line spacing, and alignment, then save. Unicode export starts with bundled Vazirmatn. Compatibility export requires a Maryam-compatible TTF or OTF font.\n\nMore options provides fixed dimensions, padding, precision, fill color, font index, and variable-font axes. Automatic width and height are enabled by default."
        },
        {
            heading: "Undo, Redo, and panel lifetime",
            body: "Use the header buttons to undo and redo source edits. Express retains up to 100 history states while the panel remains loaded. The selected editor text size is also saved."
        },
        {
            heading: "Keyboard shortcuts",
            body: "Ctrl+Enter: Convert\nCtrl+,: Toggle Settings\nCtrl+T: Toggle Text Tools\nCtrl+E: Toggle Export\nCtrl+H: Toggle Help\nCtrl+Z: Undo\nCtrl+Y or Ctrl+Shift+Z: Redo\nCtrl+Scroll up: Increase editor text size\nCtrl+Scroll down: Decrease editor text size"
        },
        {
            heading: "Troubleshooting, settings, and privacy",
            body: "If output is disconnected, reversed, or appears as unrelated symbols, check the shaping profile, conversion mode, destination font, and bidi option. Compatibility output requires its matching Maryam-compatible font.\n\nExpress saves interface, editor font size, shaping, Text tool, and SVG choices in ~/.config/leomoon-studios.omarchy-parsinegar-express/settings.json. It does not save drafts, converted text, clipboard contents, or undo history."
        }
    ]

    readonly property var persianSections: [
        {
            heading: "پارسی‌نگار اکسپرس چه کاری انجام می‌دهد؟",
            body: "اکسپرس متن پارسی، عربی، کردی، اردو و عبری را برای برنامه‌هایی آماده می‌کند که شکل‌دهی یا نمایش متن دوجهته را درست انجام نمی‌دهند. متن را وارد یا بچسبانید، نمایهٔ شکل‌دهی و حالت تبدیل را انتخاب کنید و تبدیل را بزنید. نتیجه در کلیپ‌بورد کپی می‌شود.\n\nاکسپرس صورت نویسه‌ها و ترتیب دیداری را تغییر می‌دهد، نه فونت برنامهٔ مقصد را."
        },
        {
            heading: "شروع سریع",
            body: "۱. متن مبدأ را وارد یا بچسبانید. چسباندن فقط متن ساده را بدون قالب‌بندی وب‌سایت وارد می‌کند.\n۲. در تنظیمات، نمایهٔ پارسی/عربی، کردی/اردو یا عبری را انتخاب کنید.\n۳. مگر آن‌که برنامهٔ مقصد به فونت مریم نیاز داشته باشد، حالت یونیکد را انتخاب کنید.\n۴. فقط اگر برنامهٔ مقصد راست‌به‌چپ را پشتیبانی نمی‌کند، ترتیب نمایشی دوجهته را فعال کنید.\n۵. ابزارهای متن لازم را فعال کنید و تبدیل را بزنید.\n۶. نتیجه را در برنامهٔ مقصد بچسبانید."
        },
        {
            heading: "حالت تبدیل و جهت متن",
            body: "حالت یونیکد انتخاب معمول برای برنامه‌های جدید است. حالت سازگاری برای برنامه‌های قدیمی است که به نگاشت مریم یا LMN و فونت هماهنگ نیاز دارند. عبری فقط با یونیکد کار می‌کند.\n\nجهت هر پاراگراف از نخستین نویسهٔ قوی آن تعیین می‌شود. ترتیب نمایشی دوجهته هر پاراگراف را جداگانه پردازش می‌کند و اگر برنامهٔ مقصد متن دوجهته را درست نمایش می‌دهد، باید خاموش بماند."
        },
        {
            heading: "ابزارهای متن",
            body: "هر ابزار متن کلید مستقل دارد. ابزارهای فعال درست پیش از تبدیل با هم اجرا می‌شوند، متن مبدأ را به‌روزرسانی می‌کنند و به‌صورت یک تغییر قابل واگردانی ثبت می‌شوند. ابزارهای وارون هم‌زمان فعال نمی‌شوند.\n\nاصلاح فاصلهٔ مجازی فعل‌های رایج را تشخیص می‌دهد، بنابراین «می خواهم» را اصلاح می‌کند و «میدان» را بی‌دلیل تغییر نمی‌دهد."
        },
        {
            heading: "خروجی SVG",
            body: "خروجی SVG متن تبدیل‌شده را به منحنی‌های برداری قابل ویرایش تبدیل می‌کند. فونت، اندازه، فاصلهٔ خطوط و تراز را انتخاب کنید و SVG را ذخیره کنید. خروجی یونیکد با وزیرمتن داخلی آغاز می‌شود و خروجی سازگاری به فونت TTF یا OTF سازگار با مریم نیاز دارد.\n\nگزینه‌های بیشتر شامل ابعاد ثابت، حاشیه، دقت، رنگ، نمایهٔ فونت و محورهای فونت متغیر است. پهنا و ارتفاع خودکار به‌صورت پیش‌فرض فعال هستند."
        },
        {
            heading: "واگردانی و ماندگاری پنل",
            body: "با کلیدهای بالای پنل می‌توانید ویرایش‌های متن را واگردانی یا دوباره انجام دهید. اکسپرس تا ۱۰۰ وضعیت را در زمان بارگذاری‌بودن پنل نگه می‌دارد. اندازهٔ انتخاب‌شدهٔ متن ویرایشگر نیز ذخیره می‌شود."
        },
        {
            heading: "میان‌برهای صفحه‌کلید",
            body: "تبدیل و صفحه‌ها\nتبدیل: \u2066Ctrl+Enter\u2069\nباز یا بستن تنظیمات: \u2066Ctrl+,\u2069\nباز یا بستن ابزارهای متن: \u2066Ctrl+T\u2069\nباز یا بستن خروجی: \u2066Ctrl+E\u2069\nباز یا بستن راهنما: \u2066Ctrl+H\u2069\n\nویرایش\nواگردانی: \u2066Ctrl+Z\u2069\nانجام دوباره: \u2066Ctrl+Y\u2069 یا \u2066Ctrl+Shift+Z\u2069\nافزایش اندازهٔ متن ویرایشگر: \u2066Ctrl+Scroll Up\u2069\nکاهش اندازهٔ متن ویرایشگر: \u2066Ctrl+Scroll Down\u2069"
        },
        {
            heading: "رفع اشکال، تنظیمات و حریم خصوصی",
            body: "اگر خروجی جدا، وارونه یا شبیه نمادهای نامرتبط است، نمایهٔ شکل‌دهی، حالت تبدیل، فونت مقصد و گزینهٔ دوجهته را بررسی کنید. خروجی سازگاری به فونت مریم هماهنگ نیاز دارد.\n\nاکسپرس زبان رابط، اندازهٔ فونت ویرایشگر، گزینه‌های شکل‌دهی، ابزارهای متن و انتخاب‌های SVG را در ~/.config/leomoon-studios.omarchy-parsinegar-express/settings.json ذخیره می‌کند. پیش‌نویس، متن تبدیل‌شده، کلیپ‌بورد و تاریخچهٔ واگردانی ذخیره نمی‌شوند."
        }
    ]

    readonly property var arabicSections: [
        {
            heading: "ما الذي يفعله بارسي‌نگار إكسبرس؟",
            body: "يُعدّ إكسبرس النصوص الفارسية والعربية والكردية والأردية والعبرية للتطبيقات التي لا تدعم التشكيل أو النص ثنائي الاتجاه دعمًا كاملًا. أدخل النص المصدر أو الصقه، واختر ملف التشكيل ووضع التحويل، ثم اختر تحويل. تُنسخ النتيجة إلى الحافظة.\n\nيغيّر إكسبرس أشكال الحروف وترتيبها المرئي، وليس خط التطبيق الهدف."
        },
        {
            heading: "البدء السريع",
            body: "1. أدخل النص المصدر أو الصقه. يلصق النص العادي من دون تنسيق مواقع الويب.\n2. اختر في الإعدادات الفارسي/العربي أو الكردي/الأردي أو العبري.\n3. اختر وضع Unicode ما لم يكن التطبيق الهدف يتطلب خطًا قديمًا متوافقًا مع Maryam.\n4. فعّل الترتيب المرئي ثنائي الاتجاه فقط عندما لا يدعم التطبيق الهدف النص من اليمين إلى اليسار.\n5. فعّل أدوات النص المطلوبة واختر تحويل.\n6. الصق النتيجة في التطبيق الهدف."
        },
        {
            heading: "أوضاع التحويل واتجاه النص",
            body: "وضع Unicode هو الاختيار المعتاد للتطبيقات الحديثة. وضع التوافق مخصص للتطبيقات القديمة التي تتطلب تعيينات Maryam أو LMN القديمة وخطًا مطابقًا. العبرية تعمل في وضع Unicode فقط.\n\nيستخدم كل فقرة في المحرر أول حرف قوي فيها لتحديد الاتجاه. يعالج الترتيب المرئي ثنائي الاتجاه الفقرات منفصلة، وينبغي أن يظل معطّلًا عندما يتعامل التطبيق الهدف مع النص ثنائي الاتجاه بصورة صحيحة."
        },
        {
            heading: "أدوات النص",
            body: "لكل أداة نص مفتاح خاص بها. تعمل الأدوات المفعّلة معًا مباشرة قبل التحويل، وتحدّث النص المصدر، ثم تصبح تعديلًا واحدًا قابلًا للتراجع. لا يمكن تفعيل التحويلات المتعاكسة معًا.\n\nتتعرف أداة ZWNJ على الأفعال الفارسية الشائعة، ولذلك تستطيع إصلاح «می خواهم» من دون تغيير كلمات غير مرتبطة مثل «میدان» بلا داعٍ."
        },
        {
            heading: "تصدير SVG",
            body: "يُنشئ تصدير SVG منحنيات متجهية قابلة للتحرير من النص المحوّل. اختر الخط وحجمه وتباعد الأسطر والمحاذاة، ثم احفظ الملف. يبدأ تصدير Unicode بخط Vazirmatn المضمّن. يتطلب تصدير التوافق خط TTF أو OTF متوافقًا مع Maryam.\n\nتوفّر الخيارات الإضافية أبعادًا ثابتة وحشوًا ودقة ولون تعبئة وفهرس خط ومحاور الخط المتغير. العرض والارتفاع التلقائيان مفعّلان افتراضيًا."
        },
        {
            heading: "التراجع والإعادة واستمرار اللوحة",
            body: "استخدم أزرار الرأس للتراجع عن تعديلات النص المصدر وإعادتها. يحتفظ إكسبرس بما يصل إلى 100 حالة محفوظة ما دامت اللوحة محمّلة. كما يُحفظ حجم النص المحدد للمحرر."
        },
        {
            heading: "اختصارات لوحة المفاتيح",
            body: "التحويل والصفحات\nتحويل: \u2066Ctrl+Enter\u2069\nفتح أو إغلاق الإعدادات: \u2066Ctrl+,\u2069\nفتح أو إغلاق أدوات النص: \u2066Ctrl+T\u2069\nفتح أو إغلاق التصدير: \u2066Ctrl+E\u2069\nفتح أو إغلاق المساعدة: \u2066Ctrl+H\u2069\n\nالتحرير\nتراجع: \u2066Ctrl+Z\u2069\nإعادة: \u2066Ctrl+Y\u2069 أو \u2066Ctrl+Shift+Z\u2069\nزيادة حجم نص المحرر: \u2066Ctrl+Scroll Up\u2069\nتقليل حجم نص المحرر: \u2066Ctrl+Scroll Down\u2069"
        },
        {
            heading: "استكشاف الأخطاء والإعدادات والخصوصية",
            body: "إذا كان الناتج مفصولًا أو معكوسًا أو يظهر كرموز غير مرتبطة، فتحقق من ملف التشكيل ووضع التحويل وخط التطبيق الهدف وخيار ثنائي الاتجاه. يتطلب ناتج التوافق خط Maryam مطابقًا.\n\nيحفظ إكسبرس لغة الواجهة وحجم خط المحرر وخيارات التشكيل وأدوات النص وخيارات SVG في ~/.config/leomoon-studios.omarchy-parsinegar-express/settings.json. لا يحفظ المسودات أو النص المحوّل أو محتويات الحافظة أو محفوظات التراجع."
        }
    ]

    readonly property var sections: controller.uiLanguage === "fa" ? persianSections : controller.uiLanguage === "ar" ? arabicSections : englishSections

    function focusPage() { backButton.forceActiveFocus() }

    Keys.onEscapePressed: function(event) {
        root.backRequested()
        event.accepted = true
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Style.space(10)

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)

            Text {
                Layout.fillWidth: true
                LayoutMirroring.enabled: false
                text: root.controller.uiText("help.title")
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
                font.bold: true
                horizontalAlignment: root.rightToLeft ? Text.AlignRight : Text.AlignLeft
            }

            HeaderActionButton {
                id: backButton
                objectName: "helpBackButton"
                iconText: root.rightToLeft ? root.typography.iconForward : root.typography.iconBack
                fontFamily: root.typography.iconFamily
                fontSize: Style.font.heading
                size: Style.space(42)
                toolTipText: root.controller.uiText("button.back")
                toolTipFontFamily: root.fontFamily
                Accessible.name: root.controller.uiText("button.back")
                onClicked: root.backRequested()
            }
        }

        ScrollView {
            id: helpScroll
            readonly property bool overflowing: helpContent.implicitHeight > height + 0.5
            readonly property real scrollGutter: overflowing ? helpScroll.ScrollBar.vertical.width + Style.space(6) : 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true
            leftPadding: root.rightToLeft ? scrollGutter : 0
            rightPadding: root.rightToLeft ? 0 : scrollGutter
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            Column {
                id: helpContent
                width: helpScroll.availableWidth
                spacing: Style.space(10)
                LayoutMirroring.enabled: false
                LayoutMirroring.childrenInherit: false

                Repeater {
                    model: root.sections

                    delegate: Rectangle {
                        id: sectionCard
                        required property var modelData
                        width: helpContent.width
                        implicitHeight: sectionContent.implicitHeight + Style.space(20)
                        color: Util.alpha(root.foreground, 0.025)
                        border.color: Util.alpha(root.foreground, 0.2)
                        border.width: Math.max(1, Style.normalBorderWidth)
                        radius: Style.cornerRadius
                        LayoutMirroring.enabled: false
                        LayoutMirroring.childrenInherit: false

                        ColumnLayout {
                            id: sectionContent
                            anchors.fill: parent
                            anchors.margins: Style.space(10)
                            spacing: Style.space(6)
                            LayoutMirroring.enabled: false
                            LayoutMirroring.childrenInherit: false

                            Text {
                                Layout.fillWidth: true
                                text: sectionCard.modelData.heading
                                textFormat: Text.PlainText
                                color: root.foreground
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.body
                                font.bold: true
                                horizontalAlignment: root.rightToLeft ? Text.AlignRight : Text.AlignLeft
                                wrapMode: Text.Wrap
                                LayoutMirroring.enabled: false
                            }

                            Text {
                                Layout.fillWidth: true
                                text: sectionCard.modelData.body
                                textFormat: Text.PlainText
                                color: Util.alpha(root.foreground, 0.78)
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.body
                                horizontalAlignment: root.rightToLeft ? Text.AlignRight : Text.AlignLeft
                                wrapMode: Text.Wrap
                                LayoutMirroring.enabled: false
                            }
                        }
                    }
                }
            }
        }
    }
}
