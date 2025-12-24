//
//  LocationWeatherService.swift
//  Project_Color
//
//  位置和天气服务
//  用于获取用户位置和当地天气信息
//

import Foundation
import CoreLocation
import WeatherKit
import SwiftUI
import Combine

/// 位置和天气信息
struct LocationWeatherInfo {
    let locationName: String        // 位置名称（区域级别）
    let temperature: Double         // 当前温度（摄氏度）
    let condition: String           // 天气状况描述
    let lowTemperature: Double      // 今日最低温度
    let highTemperature: Double     // 今日最高温度
}

/// 位置和天气服务
@MainActor
class LocationWeatherService: NSObject, ObservableObject {
    
    static let shared = LocationWeatherService()
    
    @Published var currentWeatherInfo: LocationWeatherInfo?
    @Published var isLoading = false
    
    private let locationManager = CLLocationManager()
    private let weatherService = WeatherService.shared
    private let geocoder = CLGeocoder()
    
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer  // 使用较低精度（区域级别）
    }
    
    /// 请求位置权限并获取天气信息
    func requestLocationAndWeather() async -> LocationWeatherInfo? {
        // 检查权限状态
        let status = locationManager.authorizationStatus
        
        switch status {
        case .notDetermined:
            // 请求权限
            locationManager.requestWhenInUseAuthorization()
            // 等待用户响应（通过 delegate 回调）
            try? await Task.sleep(nanoseconds: 500_000_000)  // 等待 0.5 秒
            return await requestLocationAndWeather()  // 递归检查新状态
            
        case .restricted, .denied:
            // 用户拒绝或受限，静默失败
            print("📍 位置权限被拒绝或受限")
            return nil
            
        case .authorizedWhenInUse, .authorizedAlways:
            // 已授权，获取位置和天气
            return await fetchLocationAndWeather()
            
        @unknown default:
            return nil
        }
    }
    
    /// 获取位置和天气信息
    private func fetchLocationAndWeather() async -> LocationWeatherInfo? {
        guard let location = await getCurrentLocation() else {
            print("📍 无法获取当前位置")
            return nil
        }
        
        // 并行获取位置名称和天气信息
        async let locationName = getLocationName(from: location)
        async let weatherInfo = getWeatherInfo(for: location)
        
        guard let name = await locationName,
              let weather = await weatherInfo else {
            print("📍 无法获取位置名称或天气信息")
            return nil
        }
        
        return LocationWeatherInfo(
            locationName: name,
            temperature: weather.temperature,
            condition: weather.condition,
            lowTemperature: weather.lowTemperature,
            highTemperature: weather.highTemperature
        )
    }
    
    /// 获取当前位置
    private func getCurrentLocation() async -> CLLocation? {
        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
            
            // 请求一次性位置更新
            locationManager.requestLocation()
            
            // 设置超时（10 秒）
            Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                if locationContinuation != nil {
                    locationContinuation?.resume(returning: nil)
                    locationContinuation = nil
                }
            }
        }
    }
    
    /// 反向地理编码获取位置名称（区域级别）
    private func getLocationName(from location: CLLocation) async -> String? {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }
            
            // 优先使用区/县级别的名称
            if let subLocality = placemark.subLocality {
                return subLocality
            }
            
            // 如果没有区级名称，使用城市名称
            if let locality = placemark.locality {
                return locality
            }
            
            // 如果都没有，使用行政区域名称
            if let administrativeArea = placemark.administrativeArea {
                return administrativeArea
            }
            
            return nil
        } catch {
            print("📍 反向地理编码失败: \(error)")
            return nil
        }
    }
    
    /// 获取天气信息
    private func getWeatherInfo(for location: CLLocation) async -> (temperature: Double, condition: String, lowTemperature: Double, highTemperature: Double)? {
        do {
            let weather = try await weatherService.weather(for: location)
            
            // 将温度转换为摄氏度
            let currentTemp = weather.currentWeather.temperature.converted(to: .celsius).value
            let condition = weatherConditionString(weather.currentWeather.condition)
            
            // 获取今日天气预报（最高/最低温度），也转换为摄氏度
            let todayForecast = weather.dailyForecast.first
            let lowTemp = todayForecast?.lowTemperature.converted(to: .celsius).value ?? currentTemp
            let highTemp = todayForecast?.highTemperature.converted(to: .celsius).value ?? currentTemp
            
            print("📍 天气信息: 当前 \(String(format: "%.1f", currentTemp))°C, 最低 \(String(format: "%.1f", lowTemp))°C, 最高 \(String(format: "%.1f", highTemp))°C")
            
            return (currentTemp, condition, lowTemp, highTemp)
        } catch {
            print("📍 获取天气信息失败: \(error)")
            return nil
        }
    }
    
    /// 将天气状况转换为本地化字符串
    private func weatherConditionString(_ condition: WeatherCondition) -> String {
        // 根据当前语言环境返回对应的天气描述
        let isChineseLocale = Locale.current.language.languageCode?.identifier == "zh"
        
        switch condition {
        case .clear:
            return isChineseLocale ? "晴" : "Clear"
        case .cloudy:
            return isChineseLocale ? "多云" : "Cloudy"
        case .mostlyClear:
            return isChineseLocale ? "晴间多云" : "Mostly Clear"
        case .mostlyCloudy:
            return isChineseLocale ? "大部多云" : "Mostly Cloudy"
        case .partlyCloudy:
            return isChineseLocale ? "局部多云" : "Partly Cloudy"
        case .rain:
            return isChineseLocale ? "雨" : "Rain"
        case .drizzle:
            return isChineseLocale ? "毛毛雨" : "Drizzle"
        case .heavyRain:
            return isChineseLocale ? "大雨" : "Heavy Rain"
        case .snow:
            return isChineseLocale ? "雪" : "Snow"
        case .sleet:
            return isChineseLocale ? "雨夹雪" : "Sleet"
        case .hail:
            return isChineseLocale ? "冰雹" : "Hail"
        case .thunderstorms:
            return isChineseLocale ? "雷暴" : "Thunderstorms"
        case .haze:
            return isChineseLocale ? "霾" : "Haze"
        case .smoky:
            return isChineseLocale ? "烟雾" : "Smoky"
        case .breezy:
            return isChineseLocale ? "微风" : "Breezy"
        case .windy:
            return isChineseLocale ? "大风" : "Windy"
        case .blizzard:
            return isChineseLocale ? "暴风雪" : "Blizzard"
        case .blowingSnow:
            return isChineseLocale ? "吹雪" : "Blowing Snow"
        case .freezingDrizzle:
            return isChineseLocale ? "冻毛毛雨" : "Freezing Drizzle"
        case .freezingRain:
            return isChineseLocale ? "冻雨" : "Freezing Rain"
        case .frigid:
            return isChineseLocale ? "严寒" : "Frigid"
        case .hot:
            return isChineseLocale ? "炎热" : "Hot"
        case .hurricane:
            return isChineseLocale ? "飓风" : "Hurricane"
        case .tropicalStorm:
            return isChineseLocale ? "热带风暴" : "Tropical Storm"
        case .flurries:
            return isChineseLocale ? "阵雪" : "Flurries"
        case .scatteredThunderstorms:
            return isChineseLocale ? "零星雷暴" : "Scattered Thunderstorms"
        case .strongStorms:
            return isChineseLocale ? "强风暴" : "Strong Storms"
        case .sunFlurries:
            return isChineseLocale ? "晴间阵雪" : "Sun Flurries"
        case .sunShowers:
            return isChineseLocale ? "晴间阵雨" : "Sun Showers"
        case .wintryMix:
            return isChineseLocale ? "雨雪混合" : "Wintry Mix"
        @unknown default:
            return isChineseLocale ? "未知" : "Unknown"
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationWeatherService: CLLocationManagerDelegate {
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            locationContinuation?.resume(returning: location)
            locationContinuation = nil
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("📍 位置更新失败: \(error)")
        
        Task { @MainActor in
            locationContinuation?.resume(returning: nil)
            locationContinuation = nil
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        print("📍 位置权限状态变化: \(status.rawValue)")
    }
}

