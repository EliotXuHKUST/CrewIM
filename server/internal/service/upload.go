package service

import (
	"os"
	"path/filepath"

	"github.com/google/uuid"
)

func SaveFile(dir string, data []byte, ext string) (string, error) {
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", err
	}
	filename := uuid.New().String() + ext
	path := filepath.Join(dir, filename)
	return path, os.WriteFile(path, data, 0o644)
}
