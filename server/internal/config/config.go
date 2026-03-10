package config

import "os"

type Config struct {
	Port              string
	DatabaseURL       string
	RedisURL          string
	JWTSecret         string
	OpenRouterKey     string
	AnthropicKey      string
	OpenAIKey         string
	WhisperAPIURL     string
	UploadDir         string
	SMSProvider       string
	TencentSMSAppID   string
	TencentSMSSign    string
	TencentSMSTPL     string
	TencentSecretID   string
	TencentSecretKey  string
	AccountEncryptKey string
	ASRProvider       string
}

func Load() *Config {
	return &Config{
		Port:              getEnv("PORT", "3000"),
		DatabaseURL:       getEnv("DATABASE_URL", "postgres://postgres:postgres@localhost:5433/command_center?sslmode=disable"),
		RedisURL:          getEnv("REDIS_URL", "redis://localhost:6379"),
		JWTSecret:         getEnv("JWT_SECRET", "dev-secret-change-me"),
		OpenRouterKey:     getEnv("OPENROUTER_API_KEY", ""),
		AnthropicKey:      getEnv("ANTHROPIC_API_KEY", ""),
		OpenAIKey:         getEnv("OPENAI_API_KEY", ""),
		WhisperAPIURL:     getEnv("WHISPER_API_URL", "https://api.openai.com/v1/audio/transcriptions"),
		UploadDir:         getEnv("UPLOAD_DIR", "./uploads"),
		SMSProvider:       getEnv("SMS_PROVIDER", "mock"),
		TencentSMSAppID:   getEnv("TENCENT_SMS_SDK_APP_ID", ""),
		TencentSMSSign:    getEnv("TENCENT_SMS_SIGN_NAME", ""),
		TencentSMSTPL:     getEnv("TENCENT_SMS_TEMPLATE_ID", ""),
		TencentSecretID:   getEnv("TENCENT_SECRET_ID", ""),
		TencentSecretKey:  getEnv("TENCENT_SECRET_KEY", ""),
		AccountEncryptKey: getEnv("ACCOUNT_ENCRYPT_KEY", "dev-encrypt-key-change-me-32chr"),
		ASRProvider:       getEnv("ASR_PROVIDER", "mock"),
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
