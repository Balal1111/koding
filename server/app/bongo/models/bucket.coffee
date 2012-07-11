class CBucket extends jraphical.Module

  {Model, ObjectRef, ObjectId, dash, daisy} = bongo

  @set
    broadcastable   : yes
    schema          :
      anchor        : ObjectRef
      group         : [ObjectRef]
      groupedBy     : String
      sourceName    : String # TODO: not sure if this is correct - C.T.
      snapshot      : String
      snapshotIds   : [ObjectId]
      migrant       : Boolean
      meta          : require "bongo/bundles/meta"
  
  fetchTeaser:(callback)-> callback null, @
  
  add:(item, callback)->
    member = ObjectRef(item)
    @update {
      $set          :
        modifiedAt  : new Date
      $addToSet     :
        group       : member.data
    }, (err)=>
      @emit 'ItemWasAdded', member.data
      callback err

  getBucketConstructor =(groupName, role)->
    switch role
      when 'follower'
        switch groupName
          when 'source' then CFolloweeBucket
          when 'target' then CFollowerBucket
      when 'like'
        switch groupName
          when 'source' then CLikeeBucket
          when 'target' then CLikerBucket
      when 'reply'
        switch groupName
          when 'source' then CReplieeBucket
          when 'target' then CReplierBucket
  
  addToBucket =do ->
    # @helper
    addIt = (bucket, anchor, item, callback)->
      isOwn = anchor.equals item
      bucket.add item, (err)->
        if err
          callback err
        else
          jraphical.Relationship.one {
            targetId: bucket.getId()
            sourceName: bucket.constructor.name + 'Activity'
            as: 'content'
          }, (err, rel)->
            if err
              callback err
            else if rel
              konstructor = bongo.Base.constructors[rel.sourceName]
              konstructor.one _id: rel.sourceId, (err, activity)->
                if err
                  callback err
                else if isOwn
                  callback null, bucket
                else
                  anchor.assureActivity activity, (err)->
                    if err
                      callback err
                    else
                      callback null, bucket
            else
              activity = CBucketActivity.create bucket
              activity.save (err)->
                if err
                  callback err
                else unless 'function' is typeof anchor.addActivity
                  callback null, bucket
                else
                  activity.addSubject bucket, (err)->
                    if err
                      callback err
                    else
                      activity.update
                        $set          :
                          snapshot    : JSON.stringify(bucket)
                        $addToSet     :
                          snapshotIds : bucket.getId()
                      , (err)->
                        if err
                          callback err
                        else if isOwn
                          callback null, bucket
                        else
                          anchor.addActivity activity, (err)->
                            if err
                              callback err
                            else
                              callback null, bucket

    (groupName, relationship, item, anchor, callback)->
      today = $gte: new Date Date.now() - 1000*60*60*12
      bucketConstructor = getBucketConstructor(
        groupName, relationship.getAt('as')
      )
      existingBucketSelector = {
        groupedBy   : groupName
        sourceName  : relationship.sourceName
        'anchor.id' : relationship[groupName+'Id']
        'meta.createdAt'   : today
      }
      bucketConstructor.one existingBucketSelector, (err, bucket)->
        if err then callback err
        else if bucket
          addIt bucket, anchor, item, callback
        else
          bucket = new bucketConstructor
            groupedBy         : groupName
            sourceName        : relationship.sourceName
            anchor            :
              constructorName : relationship[groupName+'Name']
              id              : relationship[groupName+'Id']

          bucket.save (err)->
            if err then callback err
            else addIt bucket, anchor, item, callback
  
  getPopulator =(items..., callback)->
    -> ObjectRef.populate items, (err, populated)-> callback err, populated
  
  # @implementation  
  @addActivities =(relationship, source, target, callback)->
    queue = []
    next = -> queue.next()
    # TODO: it can be horribly inefficient to convert things to and from objectrefs
    #       favor programmer convenience for now, however. C.T.
    if ObjectRef.isObjectRef(source)
      queue.push getPopulator source, (err, populated)->
        [source] = populated
        queue.next(err)
    if ObjectRef.isObjectRef(target)
      queue.push getPopulator target, (err, populated)->
        [target] = populated
        queue.next(err)
    queue.push -> addToBucket 'source', relationship, target, source, next
    queue.push -> addToBucket 'target', relationship, source, target, next
    queue.push -> callback null
    daisy queue

class CNewMemberBucket extends CBucket
  
  @share()
  
  @set
    schema          : CBucket.schema

class CFollowerBucket extends CBucket
  
  @share()
  
  @set
    schema          : CBucket.schema


class CFolloweeBucket extends CBucket

  @share()
  
  @set
    schema          : CBucket.schema

class CReplierBucket extends CBucket

  @share()
  
  @set
    schema          : CBucket.schema
  
class CReplieeBucket extends CBucket

  @share()
  
  @set
    schema          : CBucket.schema
  
class CLikerBucket extends CBucket

  @share()
  
  @set
    schema          : CBucket.schema
  
class CLikeeBucket extends CBucket

  @share()
  
  @set
    schema          : CBucket.schema

class CBucketActivity extends CActivity
  
  @setRelationships
    subject       :
      targetType  : [
        CFollowerBucket
        CFolloweeBucket
        CNewMemberBucket
        CLikerBucket
        CLikeeBucket
        CReplierBucket
        CReplieeBucket
      ]
      as          : 'content'

  @create =({constructor:{name}})->
    new (bongo.Base.constructors[name+'Activity'] or @)

class CNewMemberBucketActivity extends CBucketActivity
  @share()
  @set
    encapsulatedBy  : CActivity
    schema          : CActivity.schema
    relationships   : CBucketActivity.relationships

class CFolloweeBucketActivity extends CBucketActivity
  @share()
  @set
    encapsulatedBy  : CActivity
    schema          : CActivity.schema
    relationships   : CBucketActivity.relationships

class CFollowerBucketActivity extends CBucketActivity
  @share()
  @set
    encapsulatedBy  : CActivity
    schema          : CActivity.schema
    relationships   : CBucketActivity.relationships

class CReplierBucketActivity extends CBucketActivity
  @share()
  @set
    encapsulatedBy  : CActivity
    schema          : CActivity.schema
    relationships   : CBucketActivity.relationships

class CReplieeBucketActivity extends CBucketActivity
  @share()
  @set
    encapsulatedBy  : CActivity
    schema          : CActivity.schema
    relationships   : CBucketActivity.relationships

class CLikerBucketActivity extends CBucketActivity
  @share()
  @set
    encapsulatedBy  : CActivity
    schema          : CActivity.schema
    relationships   : CBucketActivity.relationships

class CLikeeBucketActivity extends CBucketActivity
  @share()
  @set
    encapsulatedBy  : CActivity
    schema          : CActivity.schema
    relationships   : CBucketActivity.relationships

