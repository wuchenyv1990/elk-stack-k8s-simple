# elasticsearch 笔记
版本7.8.1

## 基本操作

---

### **创建索引**

结构
- settings
- index
    - number_of_shards:数据分片数
    - number_of_replicas:数据备份数
- mappings: 
- _all 
- _source:
    - 1.enabled:false 不保存
    - 2.includes:[f1,f2]
    - 3.excludes:[f1,f2]

```
PUT operation_log
{
  "settings" : {
    "index" : {
      "number_of_shards": 1,
      "number_of_replicas": 1
    }
  },
  "mappings" : {
    "properties" : {
      "event" : {
        "type" : "keyword",
        "fields" : {
          "keyword" : {
            "type" : "keyword",
            "ignore_above" : 256
          }
        }
      },
      "desc": {
        "type" : "text",
        "analyzer" : "ik_max_word",
        "search_analyzer" : "ik_max_word",
        "fields" : {
          "raw" : {
            "type" : "keyword"
          },
          "ik_smart_analyzer" : {
            "type" : "text",
            "analyzer" : "ik_smart"
          }
        }
      },
      "user_name" : {
        "type" : "text",
        "fields" : {
          "raw" : {
            "type" : "keyword"
          }
        }
      },
      "user_id" : {
        "type" : "long"
      },
      "log_time" : {
        "type" : "date",
        "format" : "yyyy-MM-dd HH:mm:ss||strict_date_optional_time||epoch_millis"
      }
    }
  }
}
```

### **删除索引、文档**

```
DELETE operation_log(/_doc/id)
```

### **插入文档**

- 指定id，增加版本号
- post随机文档id

```
PUT/POST operation_log/_doc/1
{
  "event" : "create_order",
  "desc" : "提交订单：123456",
  "user_name" : "小张",
  "user_id" : "1",
  "log_time" : "2020-08-08 14:00:00"
}

POST operation_log/_doc
{
  "event" : "create_order",
  "desc" : "提交订单：123456",
  "user_name" : "小张",
  "user_id" : "1",
  "log_time" : "2020-08-08 14:00:00"
}
```

### **批量插入**

  - create:如果存在则失败
  - index:总是成功

```
POST _bulk
{"create":{"_index":"operation_log","_id":1}}
{"event":"create_order","desc":"提交订单：123456","user_name":"小张","user_id":"1","log_time":"2020-08-08 14:00:00"}
{"index":{"_index":"operation_log","_id":2}}
{"event":"handle_order","desc":"处理订单：123456","user_name":"小李","user_id":"2","log_time":"2020-08-08 14:05:30"}
{"index":{"_index":"operation_log","_id":3}}
{"event":"delivery_order","desc":"订单已经发货：123456","user_name":"小明","user_id":"3", "log_time":"2020-08-08 14:15:45"}
{"index":{"_index":"operation_log","_id":4}}
{"event":"receive_package","desc":"收取包裹，订单：123456","user_name":"小快","user_id":"4", "log_time":"2020-08-08 18:20:45"}
```

### **更新**

1. 更新整个文档，同插入
2. 更新指定字段`POST`，文档不存在则不操作
   ```
    POST operation_log/_update/1
    {
      "doc" : {
        "user_name" : "小张"
       }
    }
    ```
3. 指定字段更新或插入
    ```
    POST operation_log/_update/4
    {
      "doc" : {
        "not_exist_field" : "ignore"
      },
      "upsert" : {
        "event" : "receive_package",
        "desc" : "收取包裹，订单：123456",
        "user_name" : "小快",
        "user_id" : "4",
        "log_time" : "2020-08-08 18:25:00"
      }
    }
    ```
4. 全部更新或插入
    ```
    POST /operation_log/_update/3
    {
      "doc" : {
        "event" : "delivery_order",
        "desc" : "订单已经发货：123456",
        "user_name" : "小明",
        "user_id" : "3",
        "log_time" : "2020-08-08 14:15:47"
      },
      "doc_as_upsert" : true
    }
    ```

### **批量更新**

```
POST _bulk
{"update":{"_index":"operation_log","_id":3}}
{"doc":{"log_time":"2020-08-08 14:15:46"}}
```
---

## **`查询`**

### **source filter**

```
GET operation_log/_search
{
  "_source" : ["event", "user_id"],
  "query" : {
    "match_all" : {}
  }
}
```

### **查询数量**

```
GET operation_log/_count
{
  "query" : {
    "match_all" : {}
  }
}
```

---

## **`词语级搜索`**

`不会分析检索词`

### **`term`**

```
GET operation_log/_search
{
  "query" : {
    "term" : {
      "desc.raw" : "提交订单：123456"
    }
  }
}
```

### **`terms`**

```
GET operation_log/_search
{
  "query" : {
    "terms" : {
      "desc" : ["提交","处理"]
    }
  }
}
```

### **`terms set`**

同terms，需要指定匹配多少个term
- minimum_should_match_field 指定字段表示需要匹配的个数
- minimum_should_match_script 自定义脚本表示需要匹配的个数
```
GET operation_log/_search
{
  "query" : {
    "terms_set" : {
      "desc" : {
        "terms" : ["处理","订单"],
        // "minimum_should_match_field" : "user_id"
        "minimum_should_match_script" : {
          "source" : "1"
        }
      }
    }
  }
}
```

### **`range`**

- gte >=
- gt >
- lte <=
- lt <
- format 日期格式，默认同mapping
- relation 对类型为 range 字段的查询
- time_zone UTC时区
- boost 设置查询的提升值，默认为 1.0

数字/日期，类型为 NumericRangeQuery
```
GET operation_log/_search
{
  "query": {
    "range" : {
      "user_id" : {
        "gte" : 1,
        "lte" : 2,
        "boost" : 2.0
      }
    }
  }
}
```

#### **日期**

日期格式：
1. 以固定的日期开头，可以是 now 或者是以“||”结尾的时间字符串
2. 固定日期后面可接一个或多个数学表达式
    - +1h 加一小时
    - -1d 减一天
    - /M  四舍五入到最近一月
    - 支持单位: y-Years、M-Months、w-Weeks、d-Days、h-Hours、H-Hours、m-Minutes、s-Seconds

例子：
- now + 1h   ： now的毫秒值 + 1小时
- now - 1h/d ： now的毫秒值 + 1小时，再四舍五入到最近的一天的起始：2020-08-08 00:00:00 或者 结束：2020-08-08 23:59:59.999
- 2020-07-07||-1M/M：2020-07-7 的毫秒值 - 1个月，再根据情况四舍五入到最近的一月的起始：2020-06-01 00:00:00 或者 结束：2020-06-30 23:59:59.999

1. **`gt:  2020-08-08||/M 向上舍入 2020-09-01T00:00:00.000，不包含整个8月`**
2. **`gte: 2020-08-08||/M 向下舍入 2020-08-01T00:00:00.000，包含当月`**
3. **`lt:  2020-08-08||/M 向下舍入 2020-07-31T23:59:59.999，不包含整个8月`**
4. **`lte: 2020-08-08||/M 向上舍入 2020-08-30T23:59:59.999，包含当月`**

```
GET operation_log/_search
{
  "query" : {
    "range" : {
      "log_time" : {
        "time_zone" : "+08:00",
        "gte" : "2020-08-07||/d",
        "lte" : "now-1d/d"
      }
    }
  }
}
```

#### **relation**

准备数据
```
PUT aggregate
{
  "mappings" : {
    "properties" : {
      "interval": {
        "type": "integer_range"
      }
    }
  }
}

POST _bulk
{"index":{"_index":"aggregate","_id":"1"}}
{"interval":{"gte":10,"lte":15}}
{"index":{"_index":"aggregate","_id":"2"}}
{"interval":{"gte":10,"lte":20}}
{"index":{"_index":"aggregate","_id":"3"}}
{"interval":{"gte":15,"lte":18}}
{"index":{"_index":"aggregate","_id":"4"}}
{"interval":{"gte":15,"lt":18}}
{"index":{"_index":"aggregate","_id":"5"}}
{"interval":{"gt":15,"lt":18}}
```

- INTERSECTS (Default) 有交集
    ```
    GET aggregate/_search
    {
      "query" : {
        "range" : {
          "interval": {
            "gte" : 12,
            "lte" : 17,
            "relation" : "intersects"
          }
        }
      }
    }
    ```
- CONTAINS 文档的范围字段完全包含检索关键词的范围
    ```
    GET aggregate/_search
    {
      "query" : {
        "range" : {
          "interval": {
            "gte" : 12,
            "lte" : 17,
            "relation" : "contains"
          }
        }
      }
    }
    ```
- WITHIN 文档的范围字段要完全在检索关键词的范围
    ```
    GET aggregate/_search
    {
      "query" : {
        "range" : {
          "interval": {
            "gte" : 12,
            "lte" : 17,
            "relation" : "within"
          }
        }
      }
    }
    ```

### **`模糊查询`**

- wildcard
- prefix
- fuzzy

#### **`wildcard`**

检索包含通配符表达式（未分析）字段的文档
- \* 通配符
- ? 占位符 
```
GET operation_log/_search
{
  "query" : {
    "prefix" : { 
      "desc": "处*"
    }
  }
}
```

#### **`fuzzy`**

基于Levenshtein编辑距离的相似度，模糊搜索
```
GET operation_log/_search
{
  "query" : {
    "fuzzy" : { 
      "desc": "处*"
    }
  }
}
```

#### **`prefix`**

查找指定字段包含以指定前缀的词语的文档
- fuzziness：最大编辑距离(一个字符串要与另一个字符串相同必须更改的一个字符数)，默认：AUTO
- prefix_length：不会被“模糊化”的初始字符数。这有助于减少必须检查的术语数量，默认：0
- max_expansions：fuzzy查询将扩展到的最大词语数，默认：50。
- transpositions：是否支持模糊转置(ab->ba)，：默认：false
```
GET operation_log/_search
{
  "query" : {
    "fuzzy" : { 
      "desc" : {
        "value": "订旦",
        "fuzziness": 1,
        "prefix_length": 1,
        "max_expansions": 2
      }
    }
  }
}
```

#### **`exists`**

---

## **`全文搜索`**

### **`match`**

match分词，比较倒排索引。

```
GET operation_log/_search
{
  "query" : {
    "match" : {
      "desc" : "发货"
    }
  }
}
```

### **`match_phrase`**

match_phrase的分词结果必须在被检索字段的分词中都包含，而且顺序必须相同，而且默认必须都是连续的。

slop:Token之间的位置距离容差值

```
GET operation_log/_search
{
  "query" : {
    "match_phrase" : {
      "desc" : "订单已经"
    }
  }
}
```
```
GET operation_log/_search
{
  "query" : {
      "match_phrase": {
      "desc" : {
        "query" :"订单发货",
        "slop" : 1
      }
    }
  }
}
```

### **`match_phrase_prefix`**

类似match_phrase，但会对最后一个Token在倒排索引列表中进行`通配符搜索`

max_expansions:模糊匹配数

```
GET operation_log/_search
{
  "query" : {
    "match_phrase_prefix" : {
      "desc" : "订单已经发"
    }
  }
}
```
```
GET operation_log/_search
{
  "query" : {
    "match_phrase_prefix" : {
      "desc" : {
        "query" : "订单已经发",
        "max_expansions" : 1
      }
    }
  }
}
```

### **`multi_match`**

查询可以在多个字段上执行相同的 match 查询

```
GET operation_log/_search
{
  "query" : {
    "multi_match" : {
      "query" : "发货",
      "fields" : ["desc", "desc.ik_smart_analyzer"]
    }
  }
}
```

### **`query_string`**

允许单个查询字符串中指定 AND|OR|NOT 条件((发货) OR (提交))，和 multi_match 一样，支持多字段搜索

```
GET operation_log/_search
{
  "query" : {
    "query_string" : {
      "query" : "发货 OR 提交",
      "fields" : ["desc", "desc.ik_smart_analyzer"]
    }
  }
}
```

### **`simple_query_string`**

类似query_string，忽略错误的语法，丢弃查询的无效部分。分词("发货 AND 提交" )保留AND...

- \+ AND operation
- | OR operation
- \- NOT
- " 对检索词进行 match_phrase query
- \* at the end of a term signifies a prefix query
- ( and ) 优先级
- ~N after a word signifies edit distance (fuzziness)
- ~N after a phrase signifies slop amount

```
GET operation_log/_search
{
  "query" : {
    "simple_query_string" : {
      "query" : "发货 + 提交",
      "fields" : ["desc"],
      "default_operator" : "AND"
    }
  }
}
```

### **`match_bool_prefix`**

输入文本通过分词器处理为多个term，然后基于这些term进行bool query，除了最后一个term使用前缀查询 其它都是term query
```
GET operation_log/_search
{
  "query" : {
    "match_bool_prefix" : {
      "desc" : "已经 发"
    }
  }
}
```
类似于：
```
GET operation_log/_search
{
  "query" : {
    "bool" : {
      "should" : [
        { "term" : { "desc" : "已经"}},
        { "prefix" : { "desc" : "发"}}
      ]
    }
  }
}
```

### **`intervals`**

根据匹配项的顺序和邻近程度(proximity)返回文档

出现“订单”、“123456”，中间不包括“已经”
```
GET operation_log/_search
{
  "query" : {
    "intervals" :{
      "desc" : {
          "match" : {
          "query" : "订单 123456",
          "filter" : {
            "not_containing" : {
              "any_of" : {
                "intervals" : [
                  { "match" : { "query" : "已经" } }
                ]
              }
            }
          }
        }
      }
    }
  }
}
```

---

## **`组合查询`**

### **`bool`**

1. must
2. filter
3. should
4. must_not

### ** **

