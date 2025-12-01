package com.chacha.dto;

import lombok.Data;

@Data
public class PagingDto {
    private int page;
    private int total;
    private int pageSize;
    private int pageCount;
    private int startRecordNum;
    private int endRecordNum;
}