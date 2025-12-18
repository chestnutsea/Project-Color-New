//
//  LocalizationHelper.swift
//  Project_Color
//
//  多语言支持辅助工具
//

import Foundation

// MARK: - String Extension for Localization

extension String {
    /// 本地化字符串（简化版）
    /// 使用方式：
    /// Text("tab.scanner".localized)
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    /// 本地化字符串（带注释）
    /// 使用方式：
    /// Text("tab.scanner".localized(comment: "扫描标签"))
    func localized(comment: String) -> String {
        return NSLocalizedString(self, comment: comment)
    }
    
    /// 本地化字符串（带参数）
    /// 使用方式：
    /// "greeting.user".localized(with: userName)
    func localized(with arguments: CVarArg...) -> String {
        return String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}

// MARK: - Localization Manager

/// 多语言管理器
class LocalizationManager {
    static let shared = LocalizationManager()
    
    private init() {}
    
    /// 当前语言代码（如 "en", "zh-Hans"）
    var currentLanguageCode: String {
        return Locale.current.language.languageCode?.identifier ?? "en"
    }
    
    /// 当前是否为中文
    var isChineseLanguage: Bool {
        return currentLanguageCode.hasPrefix("zh")
    }
    
    /// 当前是否为英文
    var isEnglishLanguage: Bool {
        return currentLanguageCode == "en"
    }
    
    /// 获取本地化字符串
    func localizedString(for key: String, comment: String = "") -> String {
        return NSLocalizedString(key, comment: comment)
    }
}

// MARK: - Localization Keys (可选：类型安全的 Key 定义)

/// 本地化 Key 定义（类型安全，避免拼写错误）
/// 使用方式：Text(L10n.Tab.scanner)
enum L10n {
    // MARK: - Tab Bar
    enum Tab {
        static let scanner = "tab.scanner"
        static let album = "tab.album"
        static let emerge = "tab.emerge"
        static let mine = "tab.mine"
    }
    
    // MARK: - Common
    enum Common {
        static let confirm = "common.confirm"
        static let cancel = "common.cancel"
        static let done = "common.done"
        static let delete = "common.delete"
        static let save = "common.save"
        static let loading = "common.loading"
        static let error = "common.error"
        static let success = "common.success"
    }
    
    // MARK: - Toast Messages
    enum Toast {
        static let featureInDevelopment = "toast.feature_in_development"
    }
    
    // MARK: - Mine/Kit View
    enum Mine {
        static let title = "mine.title"
        static let unlockAI = "mine.unlock_ai"
        static let cloudAlbum = "mine.cloud_album"
        static let photoDarkroom = "mine.photo_darkroom"
        static let developmentMode = "mine.development_mode"
        static let scanResultStyle = "mine.scan_result_style"
        static let colorLab = "mine.color_lab"
        static let iterationLog = "mine.iteration_log"
        static let privacyPolicy = "mine.privacy_policy"
        static let feedback = "mine.feedback"
        static let encourage = "mine.encourage"
        static let encourageSubtitle = "mine.encourage_subtitle"
        static let share = "mine.share"
        static let aboutFeelm = "mine.about_feelm"
    }
    
    // MARK: - About View
    enum About {
        static let navigationTitle = "about.navigation_title"
        static let description = "about.description"
        static let iterationLog = "about.iteration_log"
        static let privacyPolicy = "about.privacy_policy"
    }
    
    // MARK: - Photo Darkroom
    enum Darkroom {
        static let title = "darkroom.title"
        static let usePhotoTime = "darkroom.use_photo_time"
        static let favoriteOnly = "darkroom.favorite_only"
        static let scanResultStyle = "darkroom.scan_result_style"
    }
    
    // MARK: - Development Mode
    enum DevelopmentMode {
        static let tone = "development_mode.tone"
        static let shadow = "development_mode.shadow"
        static let comprehensive = "development_mode.comprehensive"
    }
    
    // MARK: - Scan Result Style
    enum ScanResultStyle {
        static let perspectiveFirst = "scan_result_style.perspective_first"
        static let compositionFirst = "scan_result_style.composition_first"
    }
    
    // MARK: - Home View
    enum Home {
        static let title = "home.title"
        static let selectPhotos = "home.select_photos"
        static let startAnalysis = "home.start_analysis"
        static let analysisHistory = "home.analysis_history"
        static let settings = "home.settings"
        static let addFeeling = "home.add_feeling"
        static let scanPrepareTitle = "home.scan_prepare_title"
        static let scanPrepareMessage = "home.scan_prepare_message"
        static let processing = "home.processing"
        static let scanPreparing = "home.scan_preparing"
        static let confirmSelection = "home.confirm_selection"
        static let feelingPlaceholder = "home.feeling_placeholder"
    }
    
    // MARK: - Favorite
    enum Favorite {
        static let title = "favorite.title"
        static let photoDate = "favorite.photo_date"
        static let cancel = "favorite.cancel"
        static let confirm = "favorite.confirm"
        static let remove = "favorite.remove"
        static let add = "favorite.add"
    }
    
    // MARK: - Album
    enum Album {
        static let title = "album.title"
        static let emptyTitle = "album.empty_title"
        static let emptyMessage = "album.empty_message"
        static let photosCount = "album.photos_count"
        static let photosCountSingular = "album.photos_count_singular"
        static let editInfo = "album.edit_info"
        static let delete = "album.delete"
        static let deleteConfirmTitle = "album.delete_confirm_title"
        static let deleteConfirmMessage = "album.delete_confirm_message"
        static let editTitle = "album.edit_title"
        static let name = "album.name"
        static let namePlaceholder = "album.name_placeholder"
        
        /// 根据照片数量返回正确的本地化字符串（单数/复数）
        static func photosCountText(count: Int) -> String {
            if count == 1 {
                return photosCountSingular.localized(with: count)
            } else {
                return photosCount.localized(with: count)
            }
        }
    }
    
    // MARK: - Analysis Library
    enum AnalysisLibrary {
        static let title = "analysis_library.title"
        static let favorites = "analysis_library.favorites"
        static let materials = "analysis_library.materials"
        static let emptyFavorites = "analysis_library.empty_favorites"
        static let emptyMaterials = "analysis_library.empty_materials"
        static let deleteConfirmTitle = "analysis_library.delete_confirm_title"
        static let deleteConfirmMessage = "analysis_library.delete_confirm_message"
        static let delete = "analysis_library.delete"
        static let cancel = "analysis_library.cancel"
    }
    
    // MARK: - Emerge View
    enum Emerge {
        static let loading = "emerge.loading"
        static let insufficientPhotos = "emerge.insufficient_photos"
        static let insufficientFavorites = "emerge.insufficient_favorites"
        static let currentScanned = "emerge.current_scanned"
        static let currentFavorited = "emerge.current_favorited"
        static let errorTitle = "emerge.error_title"
    }
    
    // MARK: - Analysis Result
    enum AnalysisResult {
        static let title = "analysis_result.title"
        static let perspective = "analysis_result.perspective"
        static let composition = "analysis_result.composition"
        static let share = "analysis_result.share"
        static let favorite = "analysis_result.favorite"
        static let aiEvaluation = "analysis_result.ai_evaluation"
        static let distribution = "analysis_result.distribution"
        static let pickerTitle = "analysis_result.picker_title"
        static let aiLoading = "analysis_result.ai_loading"
        static let aiLoadingRefresh = "analysis_result.ai_loading_refresh"
        static let aiLoadingSubtitle = "analysis_result.ai_loading_subtitle"
        static let aiError = "analysis_result.ai_error"
        static let retry = "analysis_result.retry"
        static let networkError = "analysis_result.network_error"
        static let noPerspective = "analysis_result.no_perspective"
        static let colorEvaluations = "analysis_result.color_evaluations"
        static let colorSystemsCount = "analysis_result.color_systems_count"
        static let categoryDetail = "analysis_result.category_detail"
        static let saturation = "analysis_result.saturation"
        static let brightness = "analysis_result.brightness"
        static let cumulativePercentage = "analysis_result.cumulative_percentage"
        static let brightnessCdfTitle = "analysis_result.brightness_cdf_title"
        static let brightnessCdfDescription = "analysis_result.brightness_cdf_description"
        static let brightnessCalculating = "analysis_result.brightness_calculating"
    }
    
    // MARK: - Lab View
    enum Lab {
        static let title = "lab.title"
        static let searchColor = "lab.search_color"
        static let searchColorSubtitle = "lab.search_color_subtitle"
        static let calculateColor = "lab.calculate_color"
        static let calculateColorSubtitle = "lab.calculate_color_subtitle"
        static let lookupColor = "lab.lookup_color"
    }
    
    // MARK: - 3D Color Space
    enum ThreeDView {
        static let lchExplanation = "3d_view.lch_explanation"
    }
}

